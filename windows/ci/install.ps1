[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PgRoot,
    [Parameter(Mandatory = $true)][string]$UpstreamDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$extensionDir = Join-Path $PgRoot 'share/extension'
$libraryDir = Join-Path $PgRoot 'lib'
New-Item -ItemType Directory -Force -Path $extensionDir, $libraryDir | Out-Null

$sqlFiles = @(Get-ChildItem -LiteralPath $UpstreamDir -File -Filter 'odbc_fdw--*.sql')
if ($sqlFiles.Count -ne 7) {
    throw "Expected 7 upstream odbc_fdw SQL files, found $($sqlFiles.Count)."
}
Copy-Item -LiteralPath $sqlFiles.FullName -Destination $extensionDir -Force
Copy-Item -LiteralPath (Join-Path $UpstreamDir 'odbc_fdw.control') -Destination $extensionDir -Force
Copy-Item -LiteralPath (Join-Path $UpstreamDir 'odbc_fdw.dll') -Destination $libraryDir -Force
