unit nc_short_context_host;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses SysUtils, Classes, SyncObjs, Dynlibs,
    nc_short_context_ranker;

type
    TncShortContextHost = class;
    TncShortContextLoader = class(TThread)
    private
        m_owner: TncShortContextHost;
    protected
        procedure Execute; override;
    public
        constructor Create(const owner: TncShortContextHost);
    end;

    TncShortContextHost = class(TInterfacedObject, IncShortContextReranker)
    private type
        TModelFormat = function: Integer; cdecl;
        TCreateModel = function(directory, error_text: PAnsiChar; capacity: Integer): Pointer; cdecl;
        TRunModel = function(handle: Pointer; context, query, first, second: PWideChar;
            values: PInteger; timeout_ms: Integer; audit: PDouble; audit_count: Integer;
            error_text: PAnsiChar; capacity: Integer): Integer; cdecl;
        TDestroyModel = procedure(handle: Pointer); cdecl;
    private
        m_directory, m_error: string;
        m_loader: TThread;
        m_signal: TEvent;
        m_lock: TCriticalSection;
        m_ready, m_stopping: Integer;
        m_module: TLibHandle;
        m_handle: Pointer;
        m_run: TRunModel;
        m_destroy: TDestroyModel;
        m_cache_key: string;
        m_cache_switch: Boolean;
        procedure load;
    public
        constructor Create(const directory: string; background: Boolean);
        destructor Destroy; override;
        function short_context_ready: Boolean;
        function try_switch_short_context(const request: TncShortContextRequest): Boolean;
        property last_error: string read m_error;
    end;

implementation

uses fpjson, jsonparser, nc_runtime_paths, nc_sha256, nc_io_compat;

function join_path(const base, name: string): string;
begin Result := IncludeTrailingPathDelimiter(base) + name; end;

procedure log_model_state(const message_text: string);
begin
    try
        WriteLn(StdErr, UTF8Encode('[INFO] short-context ' + message_text));
        Flush(StdErr);
    except
        // Diagnostic I/O must not affect model availability or host stability.
    end;
end;

constructor TncShortContextLoader.Create(const owner: TncShortContextHost);
begin
    inherited Create(True);
    FreeOnTerminate := False;
    m_owner := owner;
end;

procedure TncShortContextLoader.Execute;
begin
    m_owner.m_signal.WaitFor(High(Cardinal));
    if InterlockedCompareExchange(m_owner.m_stopping, 0, 0) = 0 then m_owner.load;
end;

constructor TncShortContextHost.Create(const directory: string; background: Boolean);
begin
    inherited Create;
    m_directory := ExpandFileName(directory);
    m_lock := TCriticalSection.Create;
    m_signal := TEvent.Create(nil, True, False, '');
    if background then
    begin
        // Do not compete with dictionary/long-model cold start. The first
        // eligible query schedules loading and immediately uses old ranking.
        m_loader := TncShortContextLoader.Create(Self);
        m_loader.FreeOnTerminate := False;
        m_loader.Priority := tpLower;
        m_loader.Start;
    end
    else
        load;
end;

destructor TncShortContextHost.Destroy;
begin
    InterlockedExchange(m_stopping, 1);
    if m_signal <> nil then m_signal.SetEvent;
    if m_loader <> nil then begin m_loader.WaitFor; m_loader.Free; end;
    if Assigned(m_destroy) and (m_handle <> nil) then m_destroy(m_handle);
    if m_module <> 0 then FreeLibrary(m_module);
    m_signal.Free;
    m_lock.Free;
    inherited;
end;

procedure TncShortContextHost.load;
const
    required_files: array[0..6] of string = ('exit0.int8.onnx',
        'exit1.int8.onnx', 'exit2.int8.onnx', 'exit3.int8.onnx',
        'tokenizer.bin', 'policy.bin', 'final.int8.onnx');
var
    root, hash_value: TJSONData;
    manifest: TJSONObject;
    files: TJSONObject;
    path, folder, name: string;
    model_format, file_count: Integer;
    runtime_format: TModelFormat;
    create_model: TCreateModel;
    error_text: array[0..1023] of AnsiChar;
begin
    root := nil;
    try
        folder := join_path(nc_model_directory(m_directory), 'short_context');
        root := GetJSON(UTF8Encode(TncFile.ReadAllText(
            join_path(folder, 'runtime_manifest.json'), TEncoding.UTF8)));
        if not (root is TJSONObject) then
            raise EInvalidOp.Create('Invalid short-context manifest');
        manifest := TJSONObject(root);
        model_format := manifest.Get('format', 0);
        if (not manifest.Get('enabled', False)) or
            (not (model_format in [1, 2])) or
            (manifest.Get('context_characters', 0) <> 48) or
            (manifest.Get('max_inference_ms', 0) <> 30) then
            raise EInvalidOp.Create('Unsupported short-context manifest');
        if not (manifest.Find('files') is TJSONObject) then
            raise EInvalidOp.Create('Missing short-context file manifest');
        files := TJSONObject(manifest.Find('files'));
        file_count := 6;
        if model_format = 1 then Inc(file_count);
        if (files = nil) or (files.Count <> file_count) then
            raise EInvalidOp.Create('Incomplete short-context manifest');
        for name in required_files do
        begin
            if (model_format = 2) and (name = 'final.int8.onnx') then Continue;
            hash_value := files.Find(UTF8Encode(name));
            if not (hash_value is TJSONString) then
                raise EInvalidOp.Create('Missing short-context asset hash');
            path := join_path(folder, name);
            if not SameText(nc_sha256_file(path), UTF8Decode(hash_value.AsString)) then
                raise EInvalidOp.Create('Short-context asset hash mismatch');
        end;
        m_module := LoadLibrary(UTF8Encode(nc_runtime_library(m_directory)));
        if m_module = 0 then
            raise EInvalidOp.Create('Short-context runtime library unavailable');
        runtime_format := TModelFormat(GetProcedureAddress(m_module, 'nc_sc_runtime_format'));
        if not Assigned(runtime_format) then
            raise EInvalidOp.Create('Short-context runtime must be rebuilt');
        if runtime_format() <> 2 then
            raise EInvalidOp.Create('Unsupported short-context runtime format');
        create_model := TCreateModel(GetProcedureAddress(m_module, 'nc_sc_create'));
        m_run := TRunModel(GetProcedureAddress(m_module, 'nc_sc_run'));
        m_destroy := TDestroyModel(GetProcedureAddress(m_module, 'nc_sc_destroy'));
        if not Assigned(create_model) or not Assigned(m_run) or not Assigned(m_destroy) then
            raise EInvalidOp.Create('Short-context runtime ABI unavailable');
        m_handle := create_model(PAnsiChar(UTF8Encode(folder)), @error_text[0], Length(error_text));
        if m_handle = nil then raise EInvalidOp.Create(UTF8Decode(UTF8String(PAnsiChar(@error_text[0]))));
        InterlockedExchange(m_ready, 1);
        log_model_state('ready; final base-exact Top2; shared_segments=4; threads=1; deadline_ms=30');
    except
        on E: Exception do
        begin
            m_error := E.Message;
            log_model_state('unavailable; keeping baseline: ' + m_error);
        end;
    end;
    root.Free;
end;

function TncShortContextHost.short_context_ready: Boolean;
begin
    Result := InterlockedCompareExchange(m_ready, 0, 0) = 1;
    if not Result then m_signal.SetEvent;
end;

function TncShortContextHost.try_switch_short_context(const request: TncShortContextRequest): Boolean;
var
    key: string;
    value, decision: Integer;
    error_text: array[0..1023] of AnsiChar;
begin
    Result := False;
    // The native ABI uses terminated UTF-16 strings; never silently truncate.
    if (Pos(#0, request.context) > 0) or (Pos(#0, request.query) > 0) or
        (Pos(#0, request.first) > 0) or (Pos(#0, request.second) > 0) then Exit;
    if not short_context_ready or not m_lock.TryEnter then Exit;
    try
        key := request.context + #0 + request.query + #0 + request.first + #0 + request.second;
        for value in request.values do key := key + #0 + IntToStr(value);
        if key = m_cache_key then Exit(m_cache_switch);
        decision := m_run(m_handle, PChar(request.context), PChar(request.query),
            PChar(request.first), PChar(request.second), @request.values[0], 30,
            nil, 0, @error_text[0], Length(error_text));
        Result := decision = 1;
        // Cache only completed decisions. Timeout/unsupported inputs retain
        // the existing result and must not poison a later successful query.
        if decision >= 0 then
        begin
            m_cache_key := key;
            m_cache_switch := Result;
        end;
    finally
        m_lock.Leave;
    end;
end;

end.
