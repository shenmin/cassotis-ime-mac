unit nc_runtime_paths;

{$mode delphiunicode}
{$codepage utf8}

interface
function nc_model_directory(const fallback: string): string;
function nc_runtime_library(const fallback: string): string;

implementation
uses SysUtils;

function nc_model_directory(const fallback: string): string;
var bundled: string;
begin
    Result := GetEnvironmentVariable('CASSOTIS_MODEL_DIRECTORY');
    if Result <> '' then Exit;
    bundled := ExpandFileName(IncludeTrailingPathDelimiter(fallback) +
        '../Resources/models');
    if DirectoryExists(bundled) then Result := bundled
    else Result := fallback;
end;

function nc_runtime_library(const fallback: string): string;
var executable_directory, bundled: string;
begin
    Result := GetEnvironmentVariable('CASSOTIS_RUNTIME_LIBRARY');
    if Result <> '' then Exit;
    executable_directory := ExtractFileDir(ParamStr(0));
    bundled := ExpandFileName(IncludeTrailingPathDelimiter(executable_directory) +
        '../Frameworks/libcassotis_ort.dylib');
    if FileExists(bundled) then Exit(bundled);
    Result := IncludeTrailingPathDelimiter(fallback) + 'libcassotis_ort.dylib';
end;

end.
