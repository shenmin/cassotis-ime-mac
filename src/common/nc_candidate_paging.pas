unit nc_candidate_paging;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

uses Types, nc_types;

const
    c_candidate_viewport_rows = 3;

type
    TncCandidateViewport = record
        expanded: Boolean;
        first_page: Integer;
        row_count: Integer;
        procedure update(const enabled: Boolean; const input_changed: Boolean;
            const current_page, total_pages: Integer;
            const expand_requested: Boolean = False);
    end;

    TncCandidateHorizontalPlacement = record
        valid: Boolean;
        anchor: TPoint;
        work_area: TRect;
        dpi: Integer;
        left: Integer;
        target_window: NativeUInt;
        target_rect: TRect;
        function update(const expanded: Boolean; const new_anchor: TPoint;
            const width, new_dpi: Integer; const new_work_area: TRect;
            const new_target_window: NativeUInt; const new_target_rect: TRect): Integer;
    end;

implementation

uses Math;

function TncCandidateHorizontalPlacement.update(const expanded: Boolean;
    const new_anchor: TPoint; const width, new_dpi: Integer;
    const new_work_area: TRect; const new_target_window: NativeUInt;
    const new_target_rect: TRect): Integer;
var same_target: Boolean;
begin
    same_target := (new_target_window <> 0) and
        (target_window = new_target_window) and
        (target_rect.Left = new_target_rect.Left) and
        (target_rect.Top = new_target_rect.Top) and
        (target_rect.Right = new_target_rect.Right) and
        (target_rect.Bottom = new_target_rect.Bottom);
    Result := new_anchor.X;
    // Selecting a different word changes the inline preview's width, not its
    // insertion point. Ignore that caret-X movement while the editor stays put.
    if expanded and valid and (same_target or
        ((target_window = 0) and (new_target_window = 0) and
        (anchor.X = new_anchor.X))) and
        (anchor.Y = new_anchor.Y) and (dpi = new_dpi) and
        (work_area.Left = new_work_area.Left) and
        (work_area.Top = new_work_area.Top) and
        (work_area.Right = new_work_area.Right) and
        (work_area.Bottom = new_work_area.Bottom) then
        Result := left;
    // A narrower page must not pull the browsing window back toward the caret.
    // Wider pages may still move left if needed to remain inside the monitor.
    Result := Max(new_work_area.Left, Min(Result, new_work_area.Right - width));
    valid := True;
    anchor := new_anchor;
    work_area := new_work_area;
    dpi := new_dpi;
    left := Result;
    target_window := new_target_window;
    target_rect := new_target_rect;
end;

procedure TncCandidateViewport.update(const enabled: Boolean;
    const input_changed: Boolean; const current_page, total_pages: Integer;
    const expand_requested: Boolean);
begin
    if input_changed or not enabled or (total_pages <= 1) then
        expanded := False;
    if enabled and (total_pages > 1) and ((current_page > 0) or
        (expand_requested and not input_changed)) then
        expanded := True;
    row_count := 0;
    if total_pages <= 0 then
    begin
        first_page := 0;
        Exit;
    end;
    row_count := 1;
    if not expanded then
    begin
        first_page := EnsureRange(current_page, 0, total_pages - 1);
        Exit;
    end;
    row_count := Min(c_candidate_viewport_rows, total_pages);
    first_page := EnsureRange(first_page, 0, total_pages - row_count);
    if current_page < first_page then first_page := current_page;
    if current_page >= first_page + row_count then
        first_page := current_page - row_count + 1;
    first_page := EnsureRange(first_page, 0, total_pages - row_count);
end;

end.
