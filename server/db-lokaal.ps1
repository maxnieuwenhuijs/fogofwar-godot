# Start de lokale ontwikkel-MySQL (zonder Docker, zonder adminrechten).
# Idempotent: draait hij al, dan meldt hij dat alleen maar.
# Achtergrond: zie server/README.md (Docker Desktop start niet op deze
# machine door een Windows-AF_UNIX-bug, 9 augustus 2026).
$basis = "$env:USERPROFILE\fogofwar-mysql"
$mysqld = Get-ChildItem "$basis\mysql-*\bin\mysqld.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $mysqld) {
    Write-Host "Geen MySQL in $basis - zie server/README.md voor de opzet."
    exit 1
}
$test = Test-NetConnection 127.0.0.1 -Port 3316 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host "MySQL draait al op 127.0.0.1:3316"
    exit 0
}
$mysqlBasis = Split-Path (Split-Path $mysqld.FullName)
Start-Process $mysqld.FullName -WindowStyle Hidden -ArgumentList @(
    "--basedir=$mysqlBasis", "--datadir=$basis\data",
    "--port=3316", "--bind-address=127.0.0.1")
Start-Sleep -Seconds 8
$test = Test-NetConnection 127.0.0.1 -Port 3316 -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Host "MySQL gestart op 127.0.0.1:3316 (data in $basis\data)"
} else {
    Write-Host "MySQL kwam niet op; kijk in $basis voor logbestanden."
    exit 1
}
