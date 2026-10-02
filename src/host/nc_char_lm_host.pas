unit nc_char_lm_host;

{ Host side of the shared character LM:
  IncCharLm over nc_lm_* in libcassotis_ort.dylib. The model
  lives in <runtime>/char_lm; any load failure
  leaves the model unavailable and every ranking unchanged.

  One session serves the engine thread (long and short rerank, latency
  sensitive) and the Tab continuation worker. Engine calls wait at most
  c_foreground_wait_ms for a running call; worker calls go through
  background_view, wait for the model and step aside while an engine call is
  waiting. }

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses SysUtils, Classes, SyncObjs, Dynlibs, nc_platform_compat, nc_char_lm;

type
    TncCharLmHost = class(TInterfacedObject, IncCharLm, IncCharLmNext)
    private type
        TCreateModel = function(directory: PAnsiChar; intra_threads: Integer;
            error_text: PAnsiChar; capacity: Integer): Pointer; cdecl;
        TScoreTexts = function(handle: Pointer; context: PWideChar; texts: PPWideChar;
            count, min_count, max_nodes: Integer; out_logp: PSingle; timeout_ms: Integer;
            error_text: PAnsiChar; capacity: Integer): Integer; cdecl;
        TScoreTextsNext = function(handle: Pointer; context: PWideChar; texts: PPWideChar;
            count, min_count, max_nodes: Integer; out_logp: PSingle; next_indices: PInteger;
            next_count, top_k: Integer; out_next_code_points: PCardinal; out_next_logp: PSingle;
            timeout_ms: Integer; error_text: PAnsiChar; capacity: Integer): Integer; cdecl;
        TDestroyModel = procedure(handle: Pointer); cdecl;
    private
        m_directory, m_error: string;
        m_threads, m_timeout_ms: Integer;
        m_loader: TThread;
        m_signal: TEvent;
        m_ready, m_stopping: Integer;
        m_module: TLibHandle;
        m_handle: Pointer;
        m_score: TScoreTexts;
        m_score_next: TScoreTextsNext;
        m_destroy: TDestroyModel;
        m_gate: TCriticalSection;
        m_foreground_waiting: Integer;
        procedure load;
        function enter_foreground: Boolean;
        function run_score(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
    public
        constructor Create(const directory: string; background: Boolean;
            intra_threads: Integer = 4; timeout_ms: Integer = 100);
        destructor Destroy; override;
        function char_lm_ready: Boolean;
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_background(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        function score_texts_next_background(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
        { The same model for a background worker (see the unit comment). }
        function background_view: IncCharLm;
        property last_error: string read m_error;
    end;

implementation

uses fpjson, jsonparser, nc_runtime_paths, nc_sha256, nc_io_compat;

const
    c_foreground_wait_ms = 60;

type
    TncCharLmLoader = class(TThread)
    private
        FOwner: TncCharLmHost;
    protected
        procedure Execute; override;
    public
        constructor Create(const owner: TncCharLmHost);
    end;

    TncCharLmBackgroundView = class(TInterfacedObject, IncCharLm, IncCharLmNext)
    private
        m_host: TncCharLmHost;
        m_keep: IncCharLm;
    public
        constructor Create(const host: TncCharLmHost);
        function char_lm_ready: Boolean;
        function score_texts(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
        function score_texts_next(const context: string; const texts: TArray<string>;
            const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
            const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
            out next_logp: TArray<Single>): Integer;
    end;

constructor TncCharLmBackgroundView.Create(const host: TncCharLmHost);
begin
    inherited Create;
    m_host := host;
    m_keep := host;
end;

function TncCharLmBackgroundView.char_lm_ready: Boolean;
begin
    Result := m_host.char_lm_ready;
end;

function TncCharLmBackgroundView.score_texts(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
begin
    Result := m_host.score_texts_background(context, texts, min_count, max_nodes, logp);
end;

function TncCharLmBackgroundView.score_texts_next(const context: string;
    const texts: TArray<string>; const min_count, max_nodes: Integer;
    const next_texts: TArray<Integer>; const top_k: Integer; out logp: TArray<Single>;
    out next_chars: TArray<string>; out next_logp: TArray<Single>): Integer;
begin
    Result := m_host.score_texts_next_background(context, texts, min_count, max_nodes,
        next_texts, top_k, logp, next_chars, next_logp);
end;

procedure log_model_state(const message_text: string);
begin
    if GetEnvironmentVariable('CASSOTIS_CHAR_LM_PROFILE') = '1' then
        WriteLn(StdErr, UTF8Encode('[INFO] char-lm ' + message_text));
end;

constructor TncCharLmLoader.Create(const owner: TncCharLmHost);
begin
    inherited Create(True);
    FOwner := owner;
end;

procedure TncCharLmLoader.Execute;
begin
    FOwner.m_signal.WaitFor(High(Cardinal));
    if InterlockedCompareExchange(FOwner.m_stopping, 0, 0) = 0 then FOwner.load;
end;

function TncCharLmHost.enter_foreground: Boolean;
var started: QWord;
begin
    started := nc_monotonic_tick_ms;
    repeat
        if m_gate.TryEnter then Exit(True);
        Sleep(1);
    until nc_monotonic_tick_ms - started >= c_foreground_wait_ms;
    Result := False;
end;

function code_point_text(const cp: Cardinal): string;
begin
    if cp > $10FFFF then Exit('');
    if (cp >= $D800) and (cp <= $DFFF) then Exit('');
    if cp < $10000 then Result := WideChar(cp)
    else Result := UnicodeString(WideChar($D800 + ((cp - $10000) shr 10))) +
        WideChar($DC00 + ((cp - $10000) and $3FF));
end;

constructor TncCharLmHost.Create(const directory: string; background: Boolean;
    intra_threads: Integer; timeout_ms: Integer);
begin
    inherited Create;
    m_directory := ExpandFileName(nc_model_directory(directory));
    m_threads := intra_threads;
    m_timeout_ms := timeout_ms;
    m_gate := TCriticalSection.Create;
    m_signal := TEvent.Create(nil, True, False, '');
    if background then
    begin
        // Load on first use so dictionary and long-model cold start come first.
        m_loader := TncCharLmLoader.Create(Self);
        m_loader.FreeOnTerminate := False;
        m_loader.Priority := tpLower;
        m_loader.Start;
    end
    else
        load;
end;

destructor TncCharLmHost.Destroy;
begin
    InterlockedExchange(m_stopping, 1);
    if m_signal <> nil then m_signal.SetEvent;
    if m_loader <> nil then begin m_loader.WaitFor; m_loader.Free; end;
    if Assigned(m_destroy) and (m_handle <> nil) then m_destroy(m_handle);
    if m_module <> 0 then UnloadLibrary(m_module);
    m_signal.Free;
    m_gate.Free;
    inherited;
end;

procedure TncCharLmHost.load;
const
    required_files: array[0..1] of string = ('char_lm.onnx', 'char_lm_vocab.bin');
var
    root, hash_value: TJSONData;
    manifest, files: TJSONObject;
    folder, name, path: string;
    folder_utf8: UTF8String;
    create_model: TCreateModel;
    error_text: array[0..1023] of AnsiChar;
begin
    root := nil;
    try
        folder := IncludeTrailingPathDelimiter(m_directory) + 'char_lm';
        root := GetJSON(UTF8Encode(TncFile.ReadAllText(IncludeTrailingPathDelimiter(folder) +
            'runtime_manifest.json', TEncoding.UTF8)));
        if not (root is TJSONObject) then
            raise EInvalidOp.Create('Invalid character LM manifest');
        manifest := TJSONObject(root);
        if manifest.Get('format', 0) <> 1 then
            raise EInvalidOp.Create('Unsupported character LM manifest');
        if not (manifest.Find('files') is TJSONObject) then
            raise EInvalidOp.Create('Incomplete character LM manifest');
        files := TJSONObject(manifest.Find('files'));
        if files.Count <> Length(required_files) then
            raise EInvalidOp.Create('Incomplete character LM manifest');
        for name in required_files do
        begin
            hash_value := files.Find(UTF8Encode(name));
            if (hash_value = nil) or (hash_value.JSONType <> jtString) then
                raise EInvalidOp.Create('Missing character LM asset hash');
            path := IncludeTrailingPathDelimiter(folder) + name;
            if not SameText(nc_sha256_file(path), UTF8Decode(hash_value.AsString)) then
                raise EInvalidOp.Create('Character LM asset hash mismatch');
        end;
        m_module := LoadLibrary(UTF8Encode(nc_runtime_library(ExtractFileDir(ParamStr(0)))));
        if m_module = 0 then
            raise EInvalidOp.Create('Character LM runtime unavailable: ' + GetLoadErrorStr);
        create_model := TCreateModel(GetProcedureAddress(m_module, 'nc_lm_create'));
        m_score := TScoreTexts(GetProcedureAddress(m_module, 'nc_lm_score'));
        m_score_next := TScoreTextsNext(GetProcedureAddress(m_module, 'nc_lm_score_next'));
        m_destroy := TDestroyModel(GetProcedureAddress(m_module, 'nc_lm_destroy'));
        if not Assigned(create_model) or not Assigned(m_score) or not Assigned(m_destroy) then
            raise EInvalidOp.Create('Character LM runtime must be rebuilt');
        folder_utf8 := UTF8Encode(folder);
        FillChar(error_text, SizeOf(error_text), 0);
        m_handle := create_model(PAnsiChar(folder_utf8), m_threads, @error_text[0], Length(error_text));
        if m_handle = nil then
            raise EInvalidOp.Create(UTF8Decode(UTF8String(PAnsiChar(@error_text[0]))));
        InterlockedExchange(m_ready, 1);
        log_model_state(Format('ready; threads=%d; deadline_ms=%d', [m_threads, m_timeout_ms]));
    except
        on E: Exception do
        begin
            m_error := E.Message;
            log_model_state('unavailable; keeping baseline: ' + m_error);
        end;
    end;
    root.Free;
end;

function TncCharLmHost.char_lm_ready: Boolean;
begin
    Result := InterlockedCompareExchange(m_ready, 0, 0) = 1;
    if not Result then m_signal.SetEvent;
end;

function TncCharLmHost.score_texts(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
var
    next_chars: TArray<string>;
    next_logp: TArray<Single>;
begin
    Result := score_texts_next(context, texts, min_count, max_nodes, nil, 0, logp,
        next_chars, next_logp);
end;

function TncCharLmHost.score_texts_background(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; out logp: TArray<Single>): Integer;
var
    next_chars: TArray<string>;
    next_logp: TArray<Single>;
begin
    Result := score_texts_next_background(context, texts, min_count, max_nodes, nil, 0, logp,
        next_chars, next_logp);
end;

function TncCharLmHost.score_texts_next(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
    const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
    out next_logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if not char_lm_ready then Exit;
    InterlockedIncrement(m_foreground_waiting);
    try
        if not enter_foreground then Exit;
    finally
        InterlockedDecrement(m_foreground_waiting);
    end;
    try
        Result := run_score(context, texts, min_count, max_nodes, next_texts, top_k, logp,
            next_chars, next_logp);
    finally
        m_gate.Release;
    end;
end;

function TncCharLmHost.score_texts_next_background(const context: string;
    const texts: TArray<string>; const min_count, max_nodes: Integer;
    const next_texts: TArray<Integer>; const top_k: Integer; out logp: TArray<Single>;
    out next_chars: TArray<string>; out next_logp: TArray<Single>): Integer;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if not char_lm_ready then Exit;
    while InterlockedCompareExchange(m_foreground_waiting, 0, 0) > 0 do
        Sleep(1);
    m_gate.Acquire;
    try
        Result := run_score(context, texts, min_count, max_nodes, next_texts, top_k, logp,
            next_chars, next_logp);
    finally
        m_gate.Release;
    end;
end;

function TncCharLmHost.background_view: IncCharLm;
begin
    Result := TncCharLmBackgroundView.Create(Self);
end;

function TncCharLmHost.run_score(const context: string; const texts: TArray<string>;
    const min_count, max_nodes: Integer; const next_texts: TArray<Integer>;
    const top_k: Integer; out logp: TArray<Single>; out next_chars: TArray<string>;
    out next_logp: TArray<Single>): Integer;
var
    pointers: TArray<PWideChar>;
    code_points: TArray<Cardinal>;
    idx: Integer;
    error_text: array[0..1023] of AnsiChar;
begin
    Result := -1;
    SetLength(logp, 0);
    SetLength(next_chars, 0);
    SetLength(next_logp, 0);
    if (Length(texts) = 0) or (min_count < 1) or (min_count > Length(texts)) then Exit;
    if (Length(next_texts) > 0) and ((top_k < 1) or (top_k > 32) or
        (Length(next_texts) > Length(texts))) then Exit;
    // The native ABI uses terminated UTF-16 strings; never silently truncate.
    if Pos(#0, context) > 0 then Exit;
    SetLength(pointers, Length(texts));
    for idx := 0 to High(texts) do
    begin
        if (texts[idx] = '') or (Pos(#0, texts[idx]) > 0) then Exit;
        pointers[idx] := PWideChar(texts[idx]);
    end;
    SetLength(logp, Length(texts));
    SetLength(next_chars, Length(next_texts) * top_k);
    SetLength(next_logp, Length(next_texts) * top_k);
    if (Length(next_texts) > 0) and Assigned(m_score_next) then
    begin
        SetLength(code_points, Length(next_texts) * top_k);
        Result := m_score_next(m_handle, PWideChar(context), @pointers[0], Length(texts),
            min_count, max_nodes, @logp[0], @next_texts[0], Length(next_texts), top_k,
            @code_points[0], @next_logp[0], m_timeout_ms, @error_text[0], Length(error_text));
        for idx := 0 to High(code_points) do
            if code_points[idx] <> 0 then
                next_chars[idx] := code_point_text(code_points[idx]);
    end
    else
        Result := m_score(m_handle, PWideChar(context), @pointers[0], Length(texts),
            min_count, max_nodes, @logp[0], m_timeout_ms, @error_text[0], Length(error_text));
    if Result < min_count then
    begin
        Result := -1;
        SetLength(logp, 0);
        SetLength(next_chars, 0);
        SetLength(next_logp, 0);
    end
    else
        SetLength(logp, Result);
end;

end.
