unit nc_platform_compat;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

const
    VK_BACK = $08;
    VK_TAB = $09;
    VK_RETURN = $0D;
    VK_SHIFT = $10;
    VK_CONTROL = $11;
    VK_MENU = $12;
    VK_ESCAPE = $1B;
    VK_SPACE = $20;
    VK_PRIOR = $21;
    VK_NEXT = $22;
    VK_END = $23;
    VK_HOME = $24;
    VK_LEFT = $25;
    VK_UP = $26;
    VK_RIGHT = $27;
    VK_DOWN = $28;
    VK_INSERT = $2D;
    VK_DELETE = $2E;
    VK_MULTIPLY = $6A;
    VK_ADD = $6B;
    VK_SUBTRACT = $6D;
    VK_DECIMAL = $6E;
    VK_DIVIDE = $6F;
    VK_F1 = $70;
    VK_F10 = $79;
    VK_F24 = $87;
    VK_LWIN = $5B;
    VK_LSHIFT = $A0;
    VK_RSHIFT = $A1;
    VK_LCONTROL = $A2;
    VK_RCONTROL = $A3;
    VK_LMENU = $A4;
    VK_RMENU = $A5;
    VK_OEM_1 = $BA;
    VK_OEM_PLUS = $BB;
    VK_OEM_COMMA = $BC;
    VK_OEM_MINUS = $BD;
    VK_OEM_PERIOD = $BE;
    VK_OEM_2 = $BF;
    VK_OEM_3 = $C0;
    VK_OEM_4 = $DB;
    VK_OEM_5 = $DC;
    VK_OEM_6 = $DD;
    VK_OEM_7 = $DE;

function nc_monotonic_tick_ms: QWord;
function QueryPerformanceCounter(out value: Int64): Boolean;
function QueryPerformanceFrequency(out value: Int64): Boolean;
function nc_quantize_single(const value: Double): Double;

implementation

uses
    SysUtils;

{$IFDEF DARWIN}
function mach_absolute_time: QWord; cdecl; external 'c';
function mach_timebase_info(var info): LongInt; cdecl; external 'c';
var timebase: record numerator, denominator: Cardinal; end;
{$ENDIF}

function nc_monotonic_tick_ms: QWord;
{$IFDEF DARWIN}
var ticks, divisor: QWord;
{$ENDIF}
begin
    {$IFDEF DARWIN}
    ticks := mach_absolute_time;
    divisor := QWord(timebase.denominator) * 1000000;
    Result := (ticks div divisor) * timebase.numerator +
        ((ticks mod divisor) * timebase.numerator) div divisor;
    {$ELSE}
    Result := SysUtils.GetTickCount64;
    {$ENDIF}
end;

function QueryPerformanceCounter(out value: Int64): Boolean;
begin
    {$IFDEF DARWIN}
    value := Int64(mach_absolute_time);
    {$ELSE}
    value := Int64(SysUtils.GetTickCount64);
    {$ENDIF}
    Result := True;
end;

function QueryPerformanceFrequency(out value: Int64): Boolean;
begin
    {$IFDEF DARWIN}
    Result := True;
    value := (Int64(1000000000) * timebase.denominator) div timebase.numerator;
    {$ELSE}
    value := 1000;
    Result := True;
    {$ENDIF}
end;

function nc_quantize_single(const value: Double): Double;
var
    quantized: Single;
begin
    quantized := value;
    Result := quantized;
end;

{$IFDEF DARWIN}
initialization
    if (mach_timebase_info(timebase) <> 0) or (timebase.numerator = 0) or
        (timebase.denominator = 0) then
        raise Exception.Create('Cannot initialize the Darwin monotonic clock');
{$ENDIF}

end.
