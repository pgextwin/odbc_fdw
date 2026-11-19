[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$UpstreamDir,
    [Parameter(Mandatory = $true)][string]$UpstreamRepository,
    [Parameter(Mandatory = $true)][string]$UpstreamRef,
    [Parameter(Mandatory = $true)][string]$UpstreamVersion,
    [Parameter(Mandatory = $true)][int]$PostgreSqlMajor,
    [Parameter(Mandatory = $true)][string]$PostgreSqlMinor,
    [string]$DistDir = 'dist'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$upstreamSha = (& git -C $UpstreamDir rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Could not read the upstream commit for package metadata' }

$assetName = "odbc_fdw-$UpstreamRef-pg$PostgreSqlMajor-windows-x64"
$stage = Join-Path $DistDir $assetName
$zipPath = Join-Path $DistDir "$assetName.zip"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }

& (Join-Path $PSScriptRoot 'install.ps1') -PgRoot $stage -UpstreamDir $UpstreamDir

# Restore the exact upstream Git blob before packaging on Windows.
& git -C $UpstreamDir -c core.autocrlf=false checkout-index --force -- LICENSE
if ($LASTEXITCODE -ne 0) { throw 'Could not restore exact upstream LICENSE bytes' }
Copy-Item (Join-Path $UpstreamDir 'LICENSE') (Join-Path $stage 'LICENSE') -Force
Copy-Item (Join-Path $UpstreamDir 'README.md') (Join-Path $stage 'UPSTREAM-README.md') -Force

@"
odbc_fdw Windows package
========================

Upstream repository: $UpstreamRepository
Upstream ref:        $UpstreamRef
Upstream commit:     $upstreamSha
Upstream version:    $UpstreamVersion
SQL default_version: 0.5.2
PostgreSQL major:    $PostgreSqlMajor
PostgreSQL tested:   $PostgreSqlMinor
Architecture:        Windows x64
Compiler:            MSVC x64
License:             PostgreSQL; see LICENSE

Install a 64-bit ODBC driver for your target database on the PostgreSQL host.
"@ | Set-Content -Path (Join-Path $stage 'PACKAGE-INFO.txt') -Encoding utf8

Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zipPath -CompressionLevel Optimal -Force
