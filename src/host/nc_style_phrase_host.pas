unit nc_style_phrase_host;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses Dynlibs, nc_platform_compat, SysUtils, Classes, Generics.Collections,
    nc_dictionary_intf, nc_local_repair_guard, nc_types;

type
    TncStylePhraseHost = class
    private type
        TEntry = function(user: Pointer; pinyin, text: PWideChar;
            weight, rank: PInteger): Integer; cdecl;
        TLm = function(user: Pointer; text: PWideChar; count: Integer;
            scores, backoffs: PInteger): Integer; cdecl;
        TRun = function(handle: Pointer; query, first, second, first_path,
            second_path: PWideChar; user: Pointer; entry: TEntry; lm: TLm;
            timeout: Cardinal; text: PWideChar; text_capacity: Integer;
            path: PWideChar; path_capacity: Integer; pinyin: PWideChar;
            py_capacity: Integer; scores, confidence: PSingle;
            proposals, encodings: PInteger; error: PAnsiChar;
            error_capacity: Integer): Integer; cdecl;
    private
        m_handle: Pointer;
        m_run: TRun;
        m_dictionary: TncDictionaryProvider;
        m_entries: TDictionary<string, TncCandidateList>;
        m_trace: TFileStream;
    public
        constructor Create(const directory: string; const module: TLibHandle;
            const handle: Pointer);
        destructor Destroy; override;
        function run(const dictionary: TncDictionaryProvider;
            const query, first, second, first_path, second_path: string;
            const timeout: Cardinal; out selected: TncValidatedRepairPath): Boolean;
    end;

implementation

uses fpjson, jsonparser, nc_io_compat, Math;

function join_path(const base, name: string): string;
begin Result := IncludeTrailingPathDelimiter(base) + name; end;

function style_entry(user: Pointer; pinyin, text: PWideChar;
    weight, rank: PInteger): Integer; cdecl;
var
    host: TncStylePhraseHost;
    values: TncCandidateList;
    item: TncCandidate;
    key, wanted: string;
    found: Boolean;
    value: Integer;
begin
    Result := -1;
    try
        host := TncStylePhraseHost(user);
        key := string(pinyin);
        wanted := string(text);
        if not host.m_entries.TryGetValue(key, values) then
        begin
            if host.m_entries.Count >= 4096 then Exit;
            host.m_dictionary.lookup_isolated_exact_component(key, values);
            host.m_entries.Add(key, values);
        end;
        weight^ := Low(Integer);
        rank^ := -1;
        found := False;
        for item in values do
            if item.text = wanted then
            begin
                if item.source = cs_user then Exit;
                if not item.has_dict_weight then Continue;
                weight^ := Max(weight^, item.dict_weight);
                found := True;
            end;
        Result := 0;
        if not found then Exit;
        rank^ := 0;
        if Length(wanted) = 1 then
            for item in values do
                if (Length(item.text) = 1) and item.has_dict_weight and
                    (item.source <> cs_user) then
                begin
                    value := item.dict_weight;
                    if (value > weight^) or ((value = weight^) and
                        (CompareStr(item.text, wanted) < 0)) then Inc(rank^);
                end;
        Result := 1;
    except
        Result := -1;
    end;
end;

function style_lm(user: Pointer; text: PWideChar; count: Integer;
    scores, backoffs: PInteger): Integer; cdecl;
var
    host: TncStylePhraseHost;
    grams: TArray<string>;
    values, backs: TArray<Integer>;
begin
    Result := 0;
    try
        if (count < 1) or (count > 4096) then Exit;
        host := TncStylePhraseHost(user);
        grams := string(text).Split([#3]);
        if (Length(grams) <> count) or not host.m_dictionary.get_char_lm_parameters(
            grams, values, backs) or (Length(values) <> count) or
            (Length(backs) <> count) then Exit;
        Move(values[0], scores^, count * SizeOf(Integer));
        Move(backs[0], backoffs^, count * SizeOf(Integer));
        Result := 1;
    except
        Result := 0;
    end;
end;

constructor TncStylePhraseHost.Create(const directory: string; const module: TLibHandle;
    const handle: Pointer);
type TAttach = function(handle: Pointer; graph, index, error: PAnsiChar;
    capacity: Integer): Integer; cdecl;
var
    attach: TAttach;
    manifest: TJSONData;
    error: array[0..1023] of AnsiChar;
begin
    inherited Create;
    m_entries := TDictionary<string, TncCandidateList>.Create;
    manifest := GetJSON(UTF8Encode(TncFile.ReadAllText(
        join_path(directory, 'style_manifest.json'), TEncoding.UTF8)));
    try
        if (not (manifest is TJSONObject)) or (TJSONObject(manifest).Get('format', 0) <> 1) or
            not TJSONObject(manifest).Get('enabled', False) then
            raise Exception.Create('Invalid style recovery manifest');
    finally manifest.Free; end;
    attach := TAttach(GetProcedureAddress(module, 'cassotis_lr_style_attach'));
    m_run := TRun(GetProcedureAddress(module, 'cassotis_lr_style_run'));
    if not Assigned(attach) or not Assigned(m_run) then
        raise Exception.Create('Style recovery bridge unavailable');
    error[0] := #0;
    if attach(handle, PAnsiChar(UTF8Encode(join_path(directory, 'style_head.onnx'))),
        PAnsiChar(UTF8Encode(join_path(directory, 'style_phrases.bin'))), @error[0], Length(error)) <> 1 then
        raise Exception.Create(UTF8Decode(UTF8String(PAnsiChar(@error[0]))));
    m_handle := handle;
    if GetEnvironmentVariable('CASSOTIS_STYLE_PHRASE_TRACE') <> '' then
        try
            m_trace := TFileStream.Create(UTF8Encode(GetEnvironmentVariable('CASSOTIS_STYLE_PHRASE_TRACE')), fmCreate);
        except
            m_trace := nil;
        end;
end;

destructor TncStylePhraseHost.Destroy;
begin
    m_trace.Free;
    m_entries.Free;
    inherited;
end;

function TncStylePhraseHost.run(const dictionary: TncDictionaryProvider;
    const query, first, second, first_path, second_path: string;
    const timeout: Cardinal; out selected: TncValidatedRepairPath): Boolean;
var
    text: array[0..32] of WideChar;
    path: array[0..64] of WideChar;
    pinyin: array[0..192] of WideChar;
    error: array[0..1023] of AnsiChar;
    scores: array[0..8] of Single;
    confidence: Single;
    proposals, encodings, status, i: Integer;
    started, finished, frequency: Int64;
    trace: TJSONObject;
    encoded: UTF8String;
    numbers: TJSONArray;
begin
    selected := Default(TncValidatedRepairPath);
    Result := False;
    if (dictionary = nil) or (Length(first) < 6) or (Length(first) > 32) then Exit;
    // Keep exact-query caches local to this request. User learning and dictionary
    // reloads can change protection even when a provider pointer stays the same.
    m_dictionary := dictionary;
    m_entries.Clear;
    QueryPerformanceFrequency(frequency);
    QueryPerformanceCounter(started);
    status := m_run(m_handle, PChar(query), PChar(first), PChar(second),
        PChar(first_path), PChar(second_path), Self, style_entry, style_lm,
        timeout, @text[0], Length(text), @path[0], Length(path),
        @pinyin[0], Length(pinyin), @scores[0], @confidence,
        @proposals, @encodings, @error[0], Length(error));
    QueryPerformanceCounter(finished);
    if status = 1 then
    begin
        selected.text := string(text);
        selected.segment_path := string(path);
        selected.aligned_pinyin := string(pinyin);
        selected.exact_path := (Length(selected.text) = Length(first)) and
            (selected.text <> first) and (StringReplace(selected.segment_path,
            #3, '', [rfReplaceAll]) = selected.text);
        selected.boundary_repaired := selected.exact_path;
        Result := selected.exact_path;
    end;
    m_entries.Clear;
    m_dictionary := nil;
    if m_trace <> nil then
    begin
        trace := TJSONObject.Create;
        try
            trace.Add('query', UTF8Encode(query));
            trace.Add('baseline', UTF8Encode(first));
            trace.Add('second', UTF8Encode(second));
            trace.Add('selected', UTF8Encode(selected.text));
            trace.Add('path', UTF8Encode(selected.segment_path));
            trace.Add('proposals', proposals);
            trace.Add('encodings', encodings);
            trace.Add('confidence', confidence);
            trace.Add('milliseconds', (finished-started)*1000.0/frequency);
            trace.Add('error', UTF8Decode(UTF8String(PAnsiChar(@error[0]))));
            numbers := TJSONArray.Create;
            for i := 0 to High(scores) do numbers.Add(scores[i]);
            trace.Add('scores', numbers);
            try
                encoded := UTF8String(trace.AsJSON) + #10;
                if Length(encoded) > 0 then m_trace.WriteBuffer(encoded[1], Length(encoded));
            except
                FreeAndNil(m_trace);
            end;
        finally trace.Free; end;
    end;
end;

end.
