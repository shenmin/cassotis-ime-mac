unit nc_chinese_script;

{$codepage utf8}
{$mode delphiunicode}
{$H+}
{$linkframework CoreFoundation}

interface

uses nc_types;

function nc_convert_chinese_script(const text: string;
    const variant: TncDictionaryVariant): string;

implementation

type
    TCFRange = record location, length: PtrInt; end;

function CFStringCreateWithCharacters(allocator: Pointer; chars: PWideChar;
    count: PtrInt): Pointer; cdecl; external name 'CFStringCreateWithCharacters';
function CFStringCreateMutableCopy(allocator: Pointer; capacity: PtrInt;
    source: Pointer): Pointer; cdecl; external name 'CFStringCreateMutableCopy';
function CFStringTransform(value, range, transform: Pointer;
    reverse: Boolean): Boolean; cdecl; external name 'CFStringTransform';
function CFStringGetLength(value: Pointer): PtrInt; cdecl; external name 'CFStringGetLength';
procedure CFStringGetCharacters(value: Pointer; range: TCFRange;
    buffer: PWideChar); cdecl; external name 'CFStringGetCharacters';
procedure CFRelease(value: Pointer); cdecl; external name 'CFRelease';

function nc_convert_chinese_script(const text: string;
    const variant: TncDictionaryVariant): string;
var
    source, mapped, transform: Pointer;
    identifier: string;
    range: TCFRange;
begin
    Result := text;
    if text = '' then Exit;
    if variant = dv_traditional then identifier := 'Simplified-Traditional'
    else identifier := 'Traditional-Simplified';
    source := CFStringCreateWithCharacters(nil, PWideChar(text), Length(text));
    if source = nil then Exit;
    try
        mapped := CFStringCreateMutableCopy(nil, 0, source);
        if mapped = nil then Exit;
        try
            transform := CFStringCreateWithCharacters(nil, PWideChar(identifier), Length(identifier));
            if transform = nil then Exit;
            try
                if not CFStringTransform(mapped, nil, transform, False) then Exit;
                range.location := 0;
                range.length := CFStringGetLength(mapped);
                SetLength(Result, range.length);
                if range.length > 0 then CFStringGetCharacters(mapped, range, PWideChar(Result));
            finally CFRelease(transform); end;
        finally CFRelease(mapped); end;
    finally CFRelease(source); end;
end;

end.
