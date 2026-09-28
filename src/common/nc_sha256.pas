unit nc_sha256;

{$codepage utf8}
{$mode delphiunicode}
{$H+}

interface

function nc_sha256_file(const path: string): string;

implementation

uses Classes, SysUtils;

type
    TCCSHA256Context = record
        count: array[0..1] of Cardinal;
        hash: array[0..7] of Cardinal;
        buffer: array[0..15] of Cardinal;
    end;

function CC_SHA256_Init(var context: TCCSHA256Context): Integer; cdecl; external 'c';
function CC_SHA256_Update(var context: TCCSHA256Context; data: Pointer;
    length: Cardinal): Integer; cdecl; external 'c';
function CC_SHA256_Final(digest: Pointer; var context: TCCSHA256Context): Integer;
    cdecl; external 'c';

function nc_sha256_file(const path: string): string;
var
    stream: TFileStream;
    context: TCCSHA256Context;
    buffer: array[0..65535] of Byte;
    digest: array[0..31] of Byte;
    count, index: Integer;
begin
    Result := '';
    stream := TFileStream.Create(UTF8Encode(path), fmOpenRead or fmShareDenyNone);
    try
        if CC_SHA256_Init(context) <> 1 then
            raise Exception.Create('Cannot initialize SHA-256');
        repeat
            count := stream.Read(buffer, SizeOf(buffer));
            if (count > 0) and (CC_SHA256_Update(context, @buffer[0], count) <> 1) then
                raise Exception.Create('Cannot update SHA-256');
        until count = 0;
        if CC_SHA256_Final(@digest[0], context) <> 1 then
            raise Exception.Create('Cannot finalize SHA-256');
        for index := 0 to High(digest) do
            Result := Result + LowerCase(IntToHex(digest[index], 2));
    finally
        stream.Free;
    end;
end;

end.
