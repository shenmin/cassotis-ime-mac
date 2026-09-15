unit nc_utf8_reader;

{$mode delphiunicode}
{$codepage utf8}

interface

uses Classes, SysUtils;

type
    // Streaming UTF-8 input for the shared dictionary importer. TextFile's
    // buffer avoids retaining multi-million-row language models in memory.
    TncUtf8Reader = class
    private
        FInput: TextFile;
        FBuffer: array[0..65535] of Byte;
        FFirst: Boolean;
        function GetEndOfStream: Boolean;
    public
        constructor Create(const path: string; const encoding: TEncoding);
        destructor Destroy; override;
        function ReadLine: string;
        property EndOfStream: Boolean read GetEndOfStream;
    end;

implementation

constructor TncUtf8Reader.Create(const path: string; const encoding: TEncoding);
begin
    inherited Create;
    AssignFile(FInput, UTF8Encode(path));
    SetTextBuf(FInput, FBuffer);
    Reset(FInput);
    FFirst := True;
end;

destructor TncUtf8Reader.Destroy;
begin
    CloseFile(FInput);
    inherited Destroy;
end;

function TncUtf8Reader.GetEndOfStream: Boolean;
begin
    Result := Eof(FInput);
end;

function TncUtf8Reader.ReadLine: string;
var raw: UTF8String;
begin
    System.ReadLn(FInput, raw);
    Result := UTF8Decode(raw);
    if FFirst and (Length(Result) > 0) and (Result[1] = #$FEFF) then
        Delete(Result, 1, 1);
    FFirst := False;
end;

end.
