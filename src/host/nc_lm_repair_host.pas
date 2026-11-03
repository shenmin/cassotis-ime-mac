unit nc_lm_repair_host;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

{ Long-sentence repair with the pinyin-conditioned character LM (model
  consolidation, steps 3 and 4). The shared LM in <runtime>\char_lm is also
  trained to rewrite engine drafts: given the typed syllables and the draft it
  returns a corrected text (nc_lm_correct in the ORT bridge DLL). Both hosts
  open the same model file, so the bridge keeps one session for them. It took
  over from the local repair encoders and the pinyin parallel generator.

  Pinyin tokens are private-use characters listed in pinyin_readings.json with
  each character's readings and each syllable's homophones. }

interface

uses
    SysUtils, Classes, SyncObjs, Dynlibs, Generics.Collections, nc_engine_intf;

type
    TncLmRepairHost = class(TInterfacedObject, IncLongLocalRepair, IncLongLocalCorrector,
        IncShortPhraseCorrector)
    private type
        TCreateModel = function(directory: PAnsiChar; intra_threads: Integer;
            error_text: PAnsiChar; capacity: Integer): Pointer; cdecl;
        TCorrect = function(handle: Pointer; context, draft: PWideChar;
            allowed_code_points: PCardinal; allowed_offsets: PInteger; width: Integer;
            out_text: PWideChar; out_capacity: Integer; out_gain: PSingle;
            timeout_ms: Integer; error_text: PAnsiChar; capacity: Integer): Integer; cdecl;
        TCorrectWith = function(handle: Pointer; context, draft: PWideChar;
            allowed_code_points: PCardinal; allowed_offsets: PInteger; width: Integer;
            candidates: PPWideChar; candidate_count, keep: Integer; floor: Single;
            candidate_gains: PSingle;
            out_text: PWideChar; out_capacity: Integer; out_gain: PSingle;
            timeout_ms: Integer; error_text: PAnsiChar; capacity: Integer): Integer; cdecl;
        TDestroyModel = procedure(handle: Pointer); cdecl;
    private
        m_directory, m_error: string;
        m_module: TLibHandle;
        m_handle: Pointer;
        m_correct: TCorrect;
        // Optional (an older bridge lacks it): the correction that also scores candidates.
        m_correct_with: TCorrectWith;
        m_destroy: TDestroyModel;
        m_readings: TDictionary<string, TArray<string>>;
        m_homophones: TDictionary<string, TArray<Cardinal>>;
        m_syllable_index: TDictionary<string, Integer>;
        m_syllable_base, m_sep, m_draft: Cardinal;
        // Characters of preceding text the model was trained to read (0: none).
        m_context_chars: Integer;
        m_ready: Boolean;
        m_loaded: TEvent;
        m_loader: TThread;
        // One correction at a time: the native handle rejects concurrent calls.
        m_run_lock: TCriticalSection;
        procedure load;
        function align(const query_text, draft_text: string;
            out syllables: TArray<string>): Boolean;
        function correct(const query_text, draft_text, preceding_text: string;
            const minimum_units, width: Integer; const candidates: TArray<string>;
            const keep: Integer; const floor: Single; out corrected_text, aligned_pinyin: string;
            out gain: Single; out candidate_gains: TArray<Single>): Integer;
    public
        { background_load loads on a lower-priority thread so the dictionary
          starts first; repairs are skipped until the model is ready. }
        constructor Create(const base_directory: string; const background_load: Boolean = True);
        destructor Destroy; override;
        function ready: Boolean;
        function wait_until_ready(const timeout_ms: Cardinal): Boolean;
        function last_error: string;
        procedure set_document_context(const document_key, preceding_text: string);
        { The corrected draft when the model prefers another text by at least
          c_lm_repair_min_gain; aligned_pinyin is set whenever the draft aligns.
          preceding_text is the text before the input; a model whose manifest
          sets correction_context_chars reads the end of its last paragraph. }
        function try_repair(const query_text, draft_text: string;
            const document_key, preceding_text: string;
            out repaired_text, aligned_pinyin: string;
            out minimum_word_ratio: Double): Boolean;
        { The syllables of the draft as the correction aligns it, joined by #3;
          '' when it does not align (one way only) or the model is not ready. }
        function align_long(const query_text, draft_text: string): string;
        { The correction of a draft of six characters or more, without a
          threshold: 1 with the preferred text and its gain, 0 when the model
          keeps the draft, -1 without an answer. Of the candidates (texts as
          long as the draft) the keep whose first changed character the model
          rates highest get their gains over the draft in candidate_gains, when
          the best of those characters reaches floor against the draft's
          (log-probability), the others NaN. The engine decides. }
        function correct_long(const query_text, draft_text, preceding_text: string;
            const candidates: TArray<string>; const keep: Integer; const floor: Single;
            out corrected_text, aligned_pinyin: string; out gain: Single;
            out candidate_gains: TArray<Single>): Integer;
        { The correction of a phrase of three to five characters, without a
          threshold: 1 with the preferred text and its gain, 0 when the model
          keeps the draft, -1 without an answer. The engine decides. }
        function correct_short_phrase(const query_text, draft_text, preceding_text: string;
            out corrected_text, aligned_pinyin: string; out gain: Single): Integer;
    end;

implementation

uses Math, nc_types, nc_char_lm, nc_platform_compat, fpjson, jsonparser, nc_char_lm_host, nc_io_compat, nc_runtime_paths, nc_sha256;

type TncLmRepairLoader = class(TThread)
    private FOwner: TncLmRepairHost;
    protected procedure Execute; override;
    public constructor Create(const owner: TncLmRepairHost);
end;

constructor TncLmRepairLoader.Create(const owner: TncLmRepairHost);
begin
    inherited Create(True);
    FOwner := owner;
    Priority := tpLower;
end;

procedure TncLmRepairLoader.Execute;
begin
    FOwner.load;
end;

function code_point_text(const cp: Cardinal): string;
begin
    if (cp > $10FFFF) or ((cp >= $D800) and (cp <= $DFFF)) then Exit('');
    if cp < $10000 then Result := WideChar(cp)
    else Result := UnicodeString(WideChar($D800 + ((cp - $10000) shr 10))) +
        WideChar($DC00 + ((cp - $10000) and $3FF));
end;

function first_code_point(const text: string): Cardinal;
begin
    Result := 0;
    if text = '' then Exit;
    Result := Ord(text[1]);
    if (Length(text) > 1) and (Result >= $D800) and (Result <= $DBFF) and
        (Ord(text[2]) >= $DC00) and (Ord(text[2]) <= $DFFF) then
        Result := $10000 + ((Result - $D800) shl 10) + (Ord(text[2]) - $DC00);
end;

const
    // Beam width and the whole-sentence log-probability margin over the draft,
    // chosen on the 8,000-sentence fiction long dev set.
    c_lm_repair_width = 2;
    // A phrase of three to five characters: widths 3 and 4 changed nothing
    // on the clause development set.
    c_short_phrase_width = 2;
    // try_repair's margin, for an engine without the shared LM; with it the
    // engine weighs correct_long's gain together with that model's.
    c_lm_repair_min_gain = 1.0;
    // The dictionary path check accepts any segmentation, as for local repair.
    c_lm_repair_word_ratio = 0.01;

constructor TncLmRepairHost.Create(const base_directory: string; const background_load: Boolean);
begin
    inherited Create;
    m_directory := ExcludeTrailingPathDelimiter(ExpandFileName(nc_model_directory(base_directory)));
    m_readings := TDictionary<string, TArray<string>>.Create;
    m_homophones := TDictionary<string, TArray<Cardinal>>.Create;
    m_syllable_index := TDictionary<string, Integer>.Create;
    m_loaded := TEvent.Create(nil, True, False, '');
    m_run_lock := TCriticalSection.Create;
    if background_load then
    begin
        m_loader := TncLmRepairLoader.Create(Self);
        m_loader.FreeOnTerminate := False;
        m_loader.Start;
    end
    else
        load;
end;

destructor TncLmRepairHost.Destroy;
begin
    if m_loader <> nil then
    begin
        m_loader.WaitFor;
        m_loader.Free;
    end;
    if Assigned(m_destroy) and (m_handle <> nil) then m_destroy(m_handle);
    if m_module <> 0 then UnloadLibrary(m_module);
    m_readings.Free;
    m_homophones.Free;
    m_syllable_index.Free;
    m_loaded.Free;
    m_run_lock.Free;
    inherited;
end;

procedure TncLmRepairHost.load;
const
    required_files: array[0..2] of string = ('char_lm.onnx', 'char_lm_vocab.bin', 'pinyin_readings.json');
var
    root, manifest_root, value: TJSONData;
    table, readings, homophones, tokens, files, manifest: TJSONObject;
    syllables, list: TJSONArray;
    folder, name: string;
    items: TArray<string>;
    points: TArray<Cardinal>;
    create_model: TCreateModel;
    error_text: array[0..1023] of AnsiChar;
    folder_utf8: UTF8String;
    i, j: Integer;
begin
    root := nil;
    manifest_root := nil;
    try
        folder := IncludeTrailingPathDelimiter(m_directory) + 'char_lm';
        manifest_root := GetJSON(UTF8Encode(TncFile.ReadAllText(
            IncludeTrailingPathDelimiter(folder) + 'runtime_manifest.json', TEncoding.UTF8)));
        if not (manifest_root is TJSONObject) then raise EInvalidOp.Create('Invalid pinyin LM manifest');
        manifest := TJSONObject(manifest_root);
        if manifest.Get('format', 0) <> 1 then raise EInvalidOp.Create('Unsupported pinyin LM manifest');
        m_context_chars := manifest.Get('correction_context_chars', 0);
        files := manifest.Find('files') as TJSONObject;
        if (files = nil) or (files.Count <> Length(required_files)) then
            raise EInvalidOp.Create('Incomplete pinyin LM manifest');
        for name in required_files do
        begin
            value := files.Find(UTF8Encode(name));
            if (value = nil) or (value.JSONType <> jtString) then
                raise EInvalidOp.Create('Missing pinyin LM asset hash');
            if not SameText(nc_sha256_file(IncludeTrailingPathDelimiter(folder) + name),
                UTF8Decode(value.AsString)) then raise EInvalidOp.Create('Pinyin LM asset hash mismatch');
        end;
        root := GetJSON(UTF8Encode(TncFile.ReadAllText(
            IncludeTrailingPathDelimiter(folder) + 'pinyin_readings.json', TEncoding.UTF8)));
        if not (root is TJSONObject) then raise EInvalidOp.Create('Invalid pinyin LM readings');
        table := TJSONObject(root);
        syllables := table.Find('syllables') as TJSONArray;
        for i := 0 to syllables.Count - 1 do m_syllable_index.AddOrSetValue(UTF8Decode(syllables.Strings[i]), i);
        tokens := table.Find('tokens') as TJSONObject;
        m_syllable_base := tokens.Get('syllable_base', 0);
        m_sep := tokens.Get('sep', 0);
        m_draft := tokens.Get('draft', 0);
        readings := table.Find('readings') as TJSONObject;
        for j := 0 to readings.Count - 1 do
        begin
            list := readings.Items[j] as TJSONArray;
            SetLength(items, list.Count);
            for i := 0 to list.Count - 1 do items[i] := UTF8Decode(list.Strings[i]);
            m_readings.AddOrSetValue(UTF8Decode(readings.Names[j]), Copy(items));
        end;
        homophones := table.Find('homophones') as TJSONObject;
        for j := 0 to homophones.Count - 1 do
        begin
            list := homophones.Items[j] as TJSONArray;
            SetLength(points, list.Count);
            for i := 0 to list.Count - 1 do points[i] := first_code_point(UTF8Decode(list.Strings[i]));
            m_homophones.AddOrSetValue(UTF8Decode(homophones.Names[j]), Copy(points));
        end;
        m_module := LoadLibrary(UTF8Encode(nc_runtime_library(ExtractFileDir(ParamStr(0)))));
        if m_module = 0 then raise EInvalidOp.Create('Pinyin LM runtime unavailable: ' + GetLoadErrorStr);
        create_model := TCreateModel(GetProcedureAddress(m_module, 'nc_lm_create'));
        m_correct := TCorrect(GetProcedureAddress(m_module, 'nc_lm_correct'));
        m_correct_with := TCorrectWith(GetProcedureAddress(m_module, 'nc_lm_correct_with'));
        m_destroy := TDestroyModel(GetProcedureAddress(m_module, 'nc_lm_destroy'));
        if not Assigned(create_model) or not Assigned(m_correct) or not Assigned(m_destroy) then
            raise EInvalidOp.Create('Pinyin LM runtime must be rebuilt');
        folder_utf8 := UTF8Encode(folder);
        m_handle := create_model(PAnsiChar(folder_utf8), nc_shared_lm_threads, @error_text[0], Length(error_text));
        if m_handle = nil then raise EInvalidOp.Create(UTF8Decode(UTF8String(PAnsiChar(@error_text[0]))));
        m_ready := True;
        if GetEnvironmentVariable('CASSOTIS_CHAR_LM_PROFILE') = '1' then
            WriteLn(StdErr, '[INFO] lm-repair ready; shared character model');
    except
        on E: Exception do m_error := E.Message;
    end;
    root.Free;
    manifest_root.Free;
    m_loaded.SetEvent;
end;

function TncLmRepairHost.ready: Boolean;
begin
    Result := (m_loaded.WaitFor(0) = wrSignaled) and m_ready;
end;

function TncLmRepairHost.wait_until_ready(const timeout_ms: Cardinal): Boolean;
begin
    Result := (m_loaded.WaitFor(timeout_ms) = wrSignaled) and m_ready;
end;

function TncLmRepairHost.last_error: string;
begin
    if m_loaded.WaitFor(0) = wrSignaled then Result := m_error
    else Result := '';
end;

procedure TncLmRepairHost.set_document_context(const document_key, preceding_text: string);
begin
end;

// The draft's syllables in the typed pinyin; apostrophes are boundaries a
// syllable may not cross. Ambiguous or impossible alignments are rejected.
function TncLmRepairHost.align(const query_text, draft_text: string;
    out syllables: TArray<string>): Boolean;
type TGrid = TArray<TArray<Integer>>;
var
    raw, compact, reading: string;
    readings: TArray<string>;
    boundary: TArray<Boolean>;
    counts, previous_offset: TGrid;
    previous_reading: TArray<TArray<string>>;
    i, j, k, finish: Integer;
    valid: Boolean;
begin
    Result := False;
    SetLength(syllables, 0);
    raw := LowerCase(query_text);
    SetLength(boundary, Length(raw) + 1);
    compact := '';
    for i := 1 to Length(raw) do
    begin
        if raw[i] = '''' then boundary[Length(compact)] := True
        else if CharInSet(raw[i], ['a'..'z']) then compact := compact + raw[i]
        else Exit;
    end;
    SetLength(counts, Length(draft_text) + 1);
    SetLength(previous_offset, Length(counts));
    SetLength(previous_reading, Length(counts));
    for i := 0 to High(counts) do
    begin
        SetLength(counts[i], Length(compact) + 1);
        SetLength(previous_offset[i], Length(compact) + 1);
        SetLength(previous_reading[i], Length(compact) + 1);
    end;
    counts[0][0] := 1;
    for i := 0 to Length(draft_text) - 1 do
    begin
        if not m_readings.TryGetValue(draft_text[i + 1], readings) then Exit;
        for j := 0 to Length(compact) - 1 do
        begin
            if counts[i][j] = 0 then Continue;
            for reading in readings do
            begin
                finish := j + Length(reading);
                if (finish > Length(compact)) or
                    (Copy(compact, j + 1, Length(reading)) <> reading) then Continue;
                valid := True;
                for k := j + 1 to finish - 1 do
                    if boundary[k] then valid := False;
                if not valid then Continue;
                if counts[i + 1][finish] = 0 then
                begin
                    previous_offset[i + 1][finish] := j;
                    previous_reading[i + 1][finish] := reading;
                end;
                counts[i + 1][finish] := counts[i + 1][finish] + counts[i][j];
                if counts[i + 1][finish] > 2 then counts[i + 1][finish] := 2;
            end;
        end;
    end;
    j := Length(compact);
    if counts[Length(draft_text)][j] <> 1 then Exit;
    SetLength(syllables, Length(draft_text));
    for i := Length(draft_text) downto 1 do
    begin
        syllables[i - 1] := previous_reading[i][j];
        j := previous_offset[i][j];
    end;
    Result := True;
end;

// The model's correction of a draft of at least minimum_units characters: 1
// with the text it prefers and the gain, 0 when it keeps the draft, -1 without
// an answer. aligned_pinyin is set whenever the draft aligns.
function TncLmRepairHost.correct(const query_text, draft_text, preceding_text: string;
    const minimum_units, width: Integer; const candidates: TArray<string>;
    const keep: Integer; const floor: Single; out corrected_text, aligned_pinyin: string;
    out gain: Single; out candidate_gains: TArray<Single>): Integer;
var
    syllables: TArray<string>;
    homophones: TArray<Cardinal>;
    allowed: TArray<Cardinal>;
    offsets: TArray<Integer>;
    context, syllable, prefix: string;
    buffer: array[0..255] of WideChar;
    error_text: array[0..1023] of AnsiChar;
    draft_point, point: Cardinal;
    texts: TArray<PWideChar>;
    i, index: Integer;
    present: Boolean;
begin
    Result := -1;
    corrected_text := '';
    aligned_pinyin := '';
    gain := 0;
    SetLength(candidate_gains, Length(candidates));
    for i := 0 to High(candidate_gains) do candidate_gains[i] := NaN;
    if not ready or (Length(draft_text) < minimum_units) or (Length(draft_text) > 40) then Exit;
    // Only BMP drafts: one UTF-16 unit per character, as the engine counts units.
    for i := 1 to Length(draft_text) do
        if ((Ord(draft_text[i]) >= $D800) and (Ord(draft_text[i]) <= $DFFF)) then Exit;
    if not align(query_text, draft_text, syllables) then Exit;
    // Training contexts are the text before the span in its paragraph.
    prefix := '';
    if m_context_chars > 0 then
    begin
        prefix := preceding_text;
        // FPC SysUtils.LastDelimiter takes AnsiString and returns a byte
        // offset. Keep paragraph slicing in UTF-16, as Delphi does.
        i := Length(prefix);
        while (i > 0) and (prefix[i] <> #10) and (prefix[i] <> #13) do Dec(i);
        if i > 0 then prefix := Copy(prefix, i + 1, MaxInt);
        prefix := Trim(prefix);
        if Length(prefix) > m_context_chars then
            prefix := Copy(prefix, Length(prefix) - m_context_chars + 1, MaxInt);
        if (prefix <> '') and ((Ord(prefix[1]) >= $DC00) and (Ord(prefix[1]) <= $DFFF)) then Delete(prefix, 1, 1);
    end;
    context := prefix + code_point_text(m_sep);
    SetLength(offsets, Length(syllables) + 1);
    SetLength(allowed, 0);
    for i := 0 to High(syllables) do
    begin
        syllable := syllables[i];
        if not m_syllable_index.TryGetValue(syllable, index) then
        begin
            aligned_pinyin := '';
            Exit;
        end;
        context := context + code_point_text(m_syllable_base + Cardinal(index));
        if aligned_pinyin <> '' then aligned_pinyin := aligned_pinyin + #3;
        aligned_pinyin := aligned_pinyin + syllable;
        offsets[i] := Length(allowed);
        draft_point := Ord(draft_text[i + 1]);
        present := False;
        if m_homophones.TryGetValue(syllable, homophones) then
            for point in homophones do
            begin
                allowed := allowed + [point];
                present := present or (point = draft_point);
            end;
        if not present then allowed := allowed + [draft_point];
    end;
    offsets[Length(syllables)] := Length(allowed);
    context := context + code_point_text(m_draft) + draft_text + code_point_text(m_sep);
    m_run_lock.Acquire;
    try
        if (Length(candidates) > 0) and (keep > 0) and Assigned(m_correct_with) then
        begin
            SetLength(texts, Length(candidates));
            for i := 0 to High(candidates) do texts[i] := PWideChar(candidates[i]);
            Result := m_correct_with(m_handle, PWideChar(context), PWideChar(draft_text),
                @allowed[0], @offsets[0], width, @texts[0], Length(texts), keep,
                floor, @candidate_gains[0], @buffer[0], Length(buffer), @gain, 0,
                @error_text[0], Length(error_text));
        end
        else
            Result := m_correct(m_handle, PWideChar(context), PWideChar(draft_text), @allowed[0],
                @offsets[0], width, @buffer[0], Length(buffer), @gain, 0,
                @error_text[0], Length(error_text));
    finally
        m_run_lock.Release;
    end;
    if Result <> 1 then
    begin
        if Result <> 0 then Result := -1;
        Exit;
    end;
    corrected_text := string(PWideChar(@buffer[0]));
    if Length(corrected_text) <> Length(draft_text) then
    begin
        corrected_text := '';
        Result := -1;
    end;
end;

function TncLmRepairHost.try_repair(const query_text, draft_text: string;
    const document_key, preceding_text: string;
    out repaired_text, aligned_pinyin: string; out minimum_word_ratio: Double): Boolean;
var
    gain: Single;
    candidate_gains: TArray<Single>;
begin
    minimum_word_ratio := 1;
    Result := (correct_long(query_text, draft_text, preceding_text, nil, 0, 0, repaired_text,
        aligned_pinyin, gain, candidate_gains) = 1) and (gain >= c_lm_repair_min_gain);
    if Result then minimum_word_ratio := c_lm_repair_word_ratio
    else repaired_text := '';
end;

function TncLmRepairHost.align_long(const query_text, draft_text: string): string;
var
    syllables: TArray<string>;
begin
    Result := '';
    if ready and align(query_text, draft_text, syllables) then
        Result := nc_join_strings(#3, syllables);
end;

function TncLmRepairHost.correct_long(const query_text, draft_text, preceding_text: string;
    const candidates: TArray<string>; const keep: Integer; const floor: Single;
    out corrected_text, aligned_pinyin: string; out gain: Single;
    out candidate_gains: TArray<Single>): Integer;
var
    settings: TFormatSettings;
begin
    settings := DefaultFormatSettings;
    settings.DecimalSeparator := '.';
    Result := correct(query_text, draft_text, preceding_text, 6, c_lm_repair_width,
        candidates, keep, floor, corrected_text, aligned_pinyin, gain, candidate_gains);
    if Assigned(nc_char_lm_long_trace) then
        nc_char_lm_long_trace('REPAIR_H'#9 + draft_text + #9 + corrected_text + #9 +
            IntToStr(Result) + #9 + FloatToStr(gain, settings));
end;

function TncLmRepairHost.correct_short_phrase(const query_text, draft_text, preceding_text: string;
    out corrected_text, aligned_pinyin: string; out gain: Single): Integer;
var
    candidate_gains: TArray<Single>;
begin
    if Length(draft_text) > 5 then
    begin
        corrected_text := '';
        aligned_pinyin := '';
        gain := 0;
        Exit(-1);
    end;
    Result := correct(query_text, draft_text, preceding_text, 3, c_short_phrase_width,
        nil, 0, 0, corrected_text, aligned_pinyin, gain, candidate_gains);
end;

end.
