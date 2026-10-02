unit nc_one_key_rerank_host;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses Classes, SyncObjs, nc_char_lm, nc_engine_intf;

type
    TncOneKeyRerankTask = record
        context_id, context_instance_id, generation_id: QWord;
        request: TncOneKeyRerankRequest;
    end;

    TncOneKeyRerankFinished = record
        task: TncOneKeyRerankTask;
        chosen: Integer;
        changed: Boolean;
    end;

    TncOneKeyRerankHost = class;
    TncOneKeyRerankWorker = class(TThread)
    private
        FOwner: TncOneKeyRerankHost;
    protected
        procedure Execute; override;
    public
        constructor Create(const owner: TncOneKeyRerankHost);
    end;

    { One latest task, one finished slot. Delivery is polled on the engine
      thread and checked against the context instance and input generation. }
    TncOneKeyRerankHost = class
    private
        FLock: TCriticalSection;
        FWakeup: TEvent;
        FWorker: TncOneKeyRerankWorker;
        FModel: IncCharLm;
        FPending: TncOneKeyRerankTask;
        FFinished: TncOneKeyRerankFinished;
        FHasPending, FHasFinished: Boolean;
        procedure WorkerExecute;
    public
        constructor Create(const model: IncCharLm);
        destructor Destroy; override;
        function Enqueue(const task: TncOneKeyRerankTask): Boolean;
        function TryPopFinishedFor(const context_id: QWord;
            out finished: TncOneKeyRerankFinished): Boolean;
    end;

implementation

uses SysUtils;

constructor TncOneKeyRerankWorker.Create(const owner: TncOneKeyRerankHost);
begin
    inherited Create(True);
    FOwner := owner;
    FreeOnTerminate := False;
end;

procedure TncOneKeyRerankWorker.Execute;
begin
    FOwner.WorkerExecute;
end;

constructor TncOneKeyRerankHost.Create(const model: IncCharLm);
begin
    inherited Create;
    FLock := TCriticalSection.Create;
    FWakeup := TEvent.Create(nil, False, False, '');
    FModel := model;
    FWorker := TncOneKeyRerankWorker.Create(Self);
    FWorker.Start;
end;

destructor TncOneKeyRerankHost.Destroy;
begin
    if FWorker <> nil then
    begin
        FWorker.Terminate;
        FWakeup.SetEvent;
        FWorker.WaitFor;
        FWorker.Free;
    end;
    FModel := nil;
    FWakeup.Free;
    FLock.Free;
    inherited;
end;

function TncOneKeyRerankHost.Enqueue(const task: TncOneKeyRerankTask): Boolean;
begin
    Result := (FModel <> nil) and (task.context_id <> 0) and
        (Length(task.request.candidates) >= 2);
    if not Result then Exit;
    FLock.Acquire;
    try
        FPending := task;
        FHasPending := True;
        FHasFinished := False;
    finally
        FLock.Release;
    end;
    FWakeup.SetEvent;
end;

procedure TncOneKeyRerankHost.WorkerExecute;
var
    finished: TncOneKeyRerankFinished;
    available: Boolean;
begin
    while not FWorker.Terminated do
    begin
        finished := Default(TncOneKeyRerankFinished);
        FLock.Acquire;
        try
            available := FHasPending;
            if available then
            begin
                finished.task := FPending;
                FPending := Default(TncOneKeyRerankTask);
                FHasPending := False;
            end;
        finally
            FLock.Release;
        end;
        if not available then
        begin
            FWakeup.WaitFor(250);
            Continue;
        end;
        finished.chosen := finished.task.request.incumbent;
        try
            finished.changed := nc_char_lm_choose_completion(FModel,
                finished.task.request.context, finished.task.request.candidates,
                finished.task.request.incumbent, finished.task.request.typed_units,
                finished.chosen) and (finished.chosen <> finished.task.request.incumbent);
        except
            // Preserve the already-visible lexical result on inference failure.
            finished.changed := False;
        end;
        FLock.Acquire;
        try
            FFinished := finished;
            FHasFinished := True;
        finally
            FLock.Release;
        end;
    end;
end;

function TncOneKeyRerankHost.TryPopFinishedFor(const context_id: QWord;
    out finished: TncOneKeyRerankFinished): Boolean;
begin
    finished := Default(TncOneKeyRerankFinished);
    FLock.Acquire;
    try
        Result := FHasFinished and (FFinished.task.context_id = context_id);
        if Result then
        begin
            finished := FFinished;
            FFinished := Default(TncOneKeyRerankFinished);
            FHasFinished := False;
        end;
    finally
        FLock.Release;
    end;
end;

end.
