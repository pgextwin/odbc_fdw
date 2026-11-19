[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PgRoot,
    [Parameter(Mandatory = $true)][string]$UpstreamDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = (Resolve-Path $UpstreamDir).Path
$vswhere = Join-Path ([Environment]::GetFolderPath('ProgramFilesX86')) 'Microsoft Visual Studio/Installer/vswhere.exe'
if (-not (Test-Path $vswhere)) { throw 'MSVC discovery tool missing' }
$vs = @(& $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath |
    Select-Object -First 1)
if (-not $vs -or -not $vs[0].Trim()) { throw 'MSVC x64 toolchain missing' }
$devCmd = Join-Path $vs[0].Trim() 'Common7/Tools/VsDevCmd.bat'
if (-not (Test-Path $devCmd)) { throw 'VsDevCmd unavailable' }

$buildCmd = Join-Path $env:RUNNER_TEMP 'odbc-fdw-build.cmd'
@"
@echo off
call "$devCmd" -arch=x64 -host_arch=x64 >nul
if errorlevel 1 exit /b %errorlevel%
pushd "$source"
if errorlevel 1 exit /b %errorlevel%
cl /nologo /O2 /MD /DWIN32 /DWIN32_NO_STATUS /D_CRT_SECURE_NO_WARNINGS ^
 /I"$PgRoot\include\server\port\win32_msvc" ^
 /I"$PgRoot\include\server\port\win32" ^
 /I"$PgRoot\include\server" /I"$PgRoot\include" ^
 /c odbc_fdw.c
if errorlevel 1 exit /b %errorlevel%
link /nologo /DLL /OUT:odbc_fdw.dll odbc_fdw.obj "$PgRoot\lib\postgres.lib" odbc32.lib
if errorlevel 1 exit /b %errorlevel%
dumpbin /nologo /exports odbc_fdw.dll
"@ | Set-Content -Path $buildCmd -Encoding ascii

& cmd.exe /d /c $buildCmd
if ($LASTEXITCODE -ne 0) { throw 'Native odbc_fdw MSVC compile/link failed' }
