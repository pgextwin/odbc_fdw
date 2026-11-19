[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$PgRoot,
    [Parameter(Mandatory = $true)][int]$PgPort,
    [Parameter(Mandatory = $true)][int]$PostgreSqlMajor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$data = Join-Path $env:RUNNER_TEMP "odbc_fdw-$PostgreSqlMajor-data"
$log = Join-Path $env:RUNNER_TEMP "odbc_fdw-$PostgreSqlMajor.log"
$pgCtl = Join-Path $PgRoot 'bin/pg_ctl.exe'
$psql = Join-Path $PgRoot 'bin/psql.exe'
$instance = "odbc_fdw_pg$PostgreSqlMajor"
$driver = Get-OdbcDriver -Name 'ODBC Driver * for SQL Server' -Platform '64-bit' |
    Sort-Object Name -Descending | Select-Object -First 1
if (-not $driver) { throw 'The runner has no 64-bit Microsoft ODBC Driver for SQL Server' }

$localDbCreated = $false
$passed = $false
try {
    & SqlLocalDB.exe create $instance
    if ($LASTEXITCODE -ne 0) { throw 'Could not create the LocalDB instance' }
    $localDbCreated = $true
    & SqlLocalDB.exe start $instance
    if ($LASTEXITCODE -ne 0) { throw 'Could not start the LocalDB instance' }

    & "$PgRoot/bin/initdb.exe" -D $data -U postgres -A trust --encoding=UTF8 --no-locale
    if ($LASTEXITCODE -ne 0) { throw 'initdb failed' }
    & $pgCtl -D $data -l $log -o "-p $PgPort -c listen_addresses=127.0.0.1" -w start
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL startup failed' }

    $psqlArgs = @('-h', '127.0.0.1', '-p', $PgPort, '-U', 'postgres', '-d', 'postgres',
        '-X', '-v', 'ON_ERROR_STOP=1', '-v', "odbc_driver={$($driver.Name)}",
        '-v', "odbc_endpoint=(localdb)\$instance")
    @'
SET statement_timeout = '30s';
CREATE EXTENSION odbc_fdw;
CREATE SERVER ci_odbc FOREIGN DATA WRAPPER odbc_fdw
    OPTIONS (odbc_driver :'odbc_driver', odbc_server :'odbc_endpoint',
             odbc_trusted_connection 'yes', odbc_trustservercertificate 'yes',
             odbc_database 'master');
CREATE USER MAPPING FOR CURRENT_USER SERVER ci_odbc;
CREATE FOREIGN TABLE ci_odbc_rows (id integer, label text) SERVER ci_odbc
    OPTIONS (sql_query 'SELECT 1 AS id, CAST(''first'' AS varchar(16)) AS label UNION ALL SELECT 2, NULL');
DO $$
BEGIN
    IF (SELECT extversion FROM pg_extension WHERE extname = 'odbc_fdw')
        IS DISTINCT FROM '0.5.2' THEN
        RAISE EXCEPTION 'Expected odbc_fdw SQL version 0.5.2';
    END IF;
    IF (SELECT array_agg(id ORDER BY id) FROM ci_odbc_rows) IS DISTINCT FROM ARRAY[1, 2]
        OR (SELECT array_agg(label ORDER BY id) FROM ci_odbc_rows)
           IS DISTINCT FROM ARRAY['first', NULL]::text[] THEN
        RAISE EXCEPTION 'ODBC scan returned unexpected rows';
    END IF;
END
$$;
'@ | & $psql @psqlArgs -f -
    if ($LASTEXITCODE -ne 0) { throw 'odbc_fdw LocalDB query failed' }
    $passed = $true
} finally {
    try {
        if (Test-Path (Join-Path $data 'postmaster.pid')) {
            & $pgCtl -D $data -m immediate -w stop
            if ($LASTEXITCODE -ne 0 -and $passed) {
                throw 'Could not stop the PostgreSQL smoke test server'
            }
        }
    } finally {
        if ($localDbCreated) {
            & SqlLocalDB.exe stop $instance -i
            & SqlLocalDB.exe delete $instance
        }
        if (-not $passed -and (Test-Path $log)) { Get-Content $log -Tail 80 }
    }
}

Write-Host "PASS: odbc_fdw PG$PostgreSqlMajor functional smoke test"
