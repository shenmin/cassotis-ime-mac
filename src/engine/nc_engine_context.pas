unit nc_engine_context;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses
    Contnrs,
    nc_types,
    nc_candidate_paging;

type
    TncEngineContext = class
    private
        FId: QWord;
        FInstanceId: QWord;
        FGeneration: QWord;
        FActive: Boolean;
        FSurroundingText: string;
        FSurroundingReported: Boolean;
        FCursorOffset: Integer;
        FComposition: string;
        FQuickInputExplicitEntry: Boolean;
        FCandidates: TncCandidateList;
        FSelectedIndex: Integer;
        FRawInputCandidate: string;
        FRawInputSelected: Boolean;
        FViewport: TncCandidateViewport;
        FCurrentPage: Integer;
        FCandidatePages: TncCandidatePages;
        FCandidateRevision: QWord;
        FCompletionText: string;
        FCompletionPinyin: string;
        FCompletionSource: TncOneKeyCompletionSource;
        FModifierShortcutPending: Boolean;
        FModifierShortcutCanceled: Boolean;
        FModifierShortcutAction: TncShortcutAction;
        FModifierShortcutKeyCode: Word;
    public
        LongCompletionPending, OneKeyRerankPending: Boolean;
        constructor Create(const context_id: QWord);
        function AdvanceGeneration(const generation_id: QWord): Boolean;
        procedure Reset;
        procedure ClearComposition;
        procedure SetComposition(const value: string);
        procedure AppendComposition(const value: string);
        function DeleteLastCompositionCharacter: Boolean;
        procedure SetCandidates(const value: TncCandidateList);
        procedure SetRawInput(const value: string; const selected: Boolean);
        procedure UpdateViewport(const enabled, input_changed: Boolean;
            const current_page, total_pages: Integer; const expand_requested: Boolean);
        procedure PublishCandidatePages(const pages: TncCandidatePages);
        procedure SetCompletion(const full_pinyin: string;
            const text: string; const source: TncOneKeyCompletionSource = okcs_none);
        procedure BeginModifierShortcut(const action: TncShortcutAction;
            const key_code: Word);
        procedure CancelModifierShortcut;
        procedure ClearModifierShortcut;
        function FinishModifierShortcut(const key_code: Word;
            out action: TncShortcutAction; out should_execute: Boolean): Boolean;
        procedure MoveSelection(const delta: Integer);
        procedure SelectCandidate(const candidate_index: Integer);
        procedure SetSurrounding(const text: string; const cursor_offset: Integer;
            const reported: Boolean = True);
        property Id: QWord read FId;
        property InstanceId: QWord read FInstanceId;
        property Generation: QWord read FGeneration;
        property Active: Boolean read FActive write FActive;
        property SurroundingReported: Boolean read FSurroundingReported;
        property SurroundingText: string read FSurroundingText;
        property CursorOffset: Integer read FCursorOffset;
        property Composition: string read FComposition;
        property QuickInputExplicitEntry: Boolean read FQuickInputExplicitEntry write FQuickInputExplicitEntry;
        property Candidates: TncCandidateList read FCandidates;
        property SelectedIndex: Integer read FSelectedIndex;
        property RawInputCandidate: string read FRawInputCandidate;
        property RawInputSelected: Boolean read FRawInputSelected;
        property Viewport: TncCandidateViewport read FViewport;
        property CandidatePages: TncCandidatePages read FCandidatePages;
        property CandidateRevision: QWord read FCandidateRevision;
        property CompletionText: string read FCompletionText;
        property CompletionPinyin: string read FCompletionPinyin;
        property CompletionSource: TncOneKeyCompletionSource read FCompletionSource;
        property ModifierShortcutPending: Boolean
            read FModifierShortcutPending;
        property ModifierShortcutKeyCode: Word
            read FModifierShortcutKeyCode;
    end;

    TncEngineContextRegistry = class
    private
        FItems: TObjectList;
        function FindIndex(const context_id: QWord): Integer;
    public
        constructor Create;
        destructor Destroy; override;
        function Add(const context_id: QWord): Boolean;
        function Remove(const context_id: QWord): Boolean;
        function Find(const context_id: QWord): TncEngineContext;
        procedure Clear;
        procedure ClearCompositions;
        function Count: Integer;
    end;

implementation

var NextContextInstance: QWord = 0;

constructor TncEngineContext.Create(const context_id: QWord);
begin
    inherited Create;
    Inc(NextContextInstance);
    FInstanceId := NextContextInstance;
    FId := context_id;
    FGeneration := 0;
    Reset;
end;

function TncEngineContext.AdvanceGeneration(const generation_id: QWord): Boolean;
begin
    Result := generation_id >= FGeneration;
    if Result then
    begin
        if generation_id <> FGeneration then
        begin
            LongCompletionPending := False;
            OneKeyRerankPending := False;
        end;
        FGeneration := generation_id;
    end;
end;

procedure TncEngineContext.Reset;
begin
    FActive := False;
    FSurroundingText := '';
    FSurroundingReported := False;
    FCursorOffset := 0;
    ClearModifierShortcut;
    ClearComposition;
end;

procedure TncEngineContext.ClearComposition;
begin
    LongCompletionPending := False;
    OneKeyRerankPending := False;
    FComposition := '';
    FRawInputCandidate := '';
    FRawInputSelected := False;
    FQuickInputExplicitEntry := False;
    SetLength(FCandidates, 0);
    FSelectedIndex := -1;
    FViewport := Default(TncCandidateViewport);
    FCurrentPage := 0;
    FCandidatePages := nil;
    Inc(FCandidateRevision);
    FCompletionText := '';
    FCompletionPinyin := '';
    FCompletionSource := okcs_none;
end;

procedure TncEngineContext.UpdateViewport(const enabled, input_changed: Boolean;
    const current_page, total_pages: Integer; const expand_requested: Boolean);
var previous: TncCandidateViewport;
begin
    previous := FViewport;
    FViewport.update(enabled, input_changed, current_page, total_pages, expand_requested);
    // Moving the active row invalidates its old action even if the same three
    // pages remain visible. A Tab-only refresh keeps all these fields intact.
    if (FCurrentPage <> current_page) or (previous.expanded <> FViewport.expanded) or
        (previous.first_page <> FViewport.first_page) or
        (previous.row_count <> FViewport.row_count) then Inc(FCandidateRevision);
    FCurrentPage := current_page;
end;

procedure TncEngineContext.PublishCandidatePages(const pages: TncCandidatePages);
var row, item: Integer; unchanged: Boolean; a, b: TncCandidate;
begin
    unchanged := Length(pages) = Length(FCandidatePages);
    row := 0;
    while unchanged and (row < Length(pages)) do
    begin
        unchanged := (pages[row].page_index = FCandidatePages[row].page_index) and
            (Length(pages[row].candidates) = Length(FCandidatePages[row].candidates));
        item := 0;
        while unchanged and (item < Length(pages[row].candidates)) do
        begin
            a := pages[row].candidates[item]; b := FCandidatePages[row].candidates[item];
            unchanged := (a.text = b.text) and (a.comment = b.comment) and
                (a.source = b.source) and (a.display_kind = b.display_kind) and
                (a.deletable = b.deletable);
            Inc(item);
        end;
        Inc(row);
    end;
    // An asynchronous Tab update does not invalidate a click on unchanged words.
    // SetComposition separately invalidates the token even if the same words return.
    if unchanged then Exit;
    FCandidatePages := Copy(pages, 0, Length(pages));
    for row := 0 to High(FCandidatePages) do
        FCandidatePages[row].candidates := Copy(pages[row].candidates);
    Inc(FCandidateRevision);
end;

procedure TncEngineContext.SetComposition(const value: string);
begin
    if FComposition <> value then Inc(FCandidateRevision);
    FComposition := value;
    if value = '' then FQuickInputExplicitEntry := False;
end;

procedure TncEngineContext.AppendComposition(const value: string);
begin
    SetComposition(FComposition + value);
end;

function TncEngineContext.DeleteLastCompositionCharacter: Boolean;
begin
    Result := Length(FComposition) > 0;
    if Result then
    begin
        Delete(FComposition, Length(FComposition), 1);
        Inc(FCandidateRevision);
    end;
end;

procedure TncEngineContext.SetRawInput(const value: string; const selected: Boolean);
begin
    if (FRawInputCandidate <> value) or (FRawInputSelected <> selected) then Inc(FCandidateRevision);
    FRawInputCandidate := value;
    FRawInputSelected := selected;
end;

procedure TncEngineContext.SetCandidates(const value: TncCandidateList);
begin
    FCandidates := Copy(value, 0, Length(value));
    if Length(FCandidates) = 0 then
        FSelectedIndex := -1
    else if (FSelectedIndex < 0) or (FSelectedIndex >= Length(FCandidates)) then
        FSelectedIndex := 0;
end;

procedure TncEngineContext.SetCompletion(const full_pinyin: string;
    const text: string; const source: TncOneKeyCompletionSource);
begin
    FCompletionPinyin := full_pinyin;
    FCompletionText := text;
    FCompletionSource := source;
    if text = '' then FCompletionSource := okcs_none;
end;

procedure TncEngineContext.BeginModifierShortcut(
    const action: TncShortcutAction; const key_code: Word);
begin
    FModifierShortcutPending := True;
    FModifierShortcutCanceled := False;
    FModifierShortcutAction := action;
    FModifierShortcutKeyCode := key_code;
end;

procedure TncEngineContext.CancelModifierShortcut;
begin
    if FModifierShortcutPending then
        FModifierShortcutCanceled := True;
end;

procedure TncEngineContext.ClearModifierShortcut;
begin
    FModifierShortcutPending := False;
    FModifierShortcutCanceled := False;
    FModifierShortcutAction := Low(TncShortcutAction);
    FModifierShortcutKeyCode := 0;
end;

function TncEngineContext.FinishModifierShortcut(const key_code: Word;
    out action: TncShortcutAction; out should_execute: Boolean): Boolean;
begin
    Result := FModifierShortcutPending and
        (FModifierShortcutKeyCode = key_code);
    action := FModifierShortcutAction;
    should_execute := Result and (not FModifierShortcutCanceled);
    if Result then
        ClearModifierShortcut;
end;

procedure TncEngineContext.MoveSelection(const delta: Integer);
begin
    if Length(FCandidates) = 0 then
    begin
        FSelectedIndex := -1;
        Exit;
    end;
    FSelectedIndex := (FSelectedIndex + delta) mod Length(FCandidates);
    if FSelectedIndex < 0 then
        Inc(FSelectedIndex, Length(FCandidates));
end;

procedure TncEngineContext.SelectCandidate(const candidate_index: Integer);
begin
    if Length(FCandidates) = 0 then
        FSelectedIndex := -1
    else if candidate_index < 0 then
        FSelectedIndex := 0
    else if candidate_index >= Length(FCandidates) then
        FSelectedIndex := Length(FCandidates) - 1
    else
        FSelectedIndex := candidate_index;
end;

procedure TncEngineContext.SetSurrounding(const text: string;
    const cursor_offset: Integer; const reported: Boolean);
begin
    FSurroundingText := text;
    FSurroundingReported := reported;
    if cursor_offset < 0 then
        FCursorOffset := 0
    else if cursor_offset > Length(text) then
        FCursorOffset := Length(text)
    else
        FCursorOffset := cursor_offset;
end;

constructor TncEngineContextRegistry.Create;
begin
    inherited Create;
    FItems := TObjectList.Create(True);
end;

destructor TncEngineContextRegistry.Destroy;
begin
    FItems.Free;
    inherited Destroy;
end;

function TncEngineContextRegistry.FindIndex(const context_id: QWord): Integer;
var
    index: Integer;
begin
    for index := 0 to FItems.Count - 1 do
        if TncEngineContext(FItems[index]).Id = context_id then
            Exit(index);
    Result := -1;
end;

function TncEngineContextRegistry.Add(const context_id: QWord): Boolean;
begin
    Result := (context_id <> 0) and (FindIndex(context_id) < 0);
    if Result then
        FItems.Add(TncEngineContext.Create(context_id));
end;

function TncEngineContextRegistry.Remove(const context_id: QWord): Boolean;
var
    index: Integer;
begin
    index := FindIndex(context_id);
    Result := index >= 0;
    if Result then
        FItems.Delete(index);
end;

function TncEngineContextRegistry.Find(
    const context_id: QWord): TncEngineContext;
var
    index: Integer;
begin
    index := FindIndex(context_id);
    if index < 0 then
        Exit(nil);
    Result := TncEngineContext(FItems[index]);
end;

procedure TncEngineContextRegistry.Clear;
begin
    FItems.Clear;
end;

procedure TncEngineContextRegistry.ClearCompositions;
var
    index: Integer;
begin
    for index := 0 to FItems.Count - 1 do
        TncEngineContext(FItems[index]).ClearComposition;
end;

function TncEngineContextRegistry.Count: Integer;
begin
    Result := FItems.Count;
end;

end.
