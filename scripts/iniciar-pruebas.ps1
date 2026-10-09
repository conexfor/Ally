# Arranca el entorno de pruebas con el teléfono real:
#   PostgreSQL portable (puerto 54329) + servidor Ally (8080) + túnel ngrok.
# Uso (desde la raíz del proyecto):  powershell -ExecutionPolicy Bypass -File scripts\iniciar-pruebas.ps1
# Cada pieza queda en su propia ventana; ciérrala para detenerla.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$pg = 'C:\Users\nicol\syncalarm-pg'
$pgBin = "$pg\node_modules\@embedded-postgres\windows-x64\native\bin"

function Test-Port($port) {
    [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

# 1. Base de datos
if (Test-Port 54329) {
    Write-Host 'PostgreSQL ya está funcionando.'
} else {
    Start-Process -FilePath "$pgBin\pg_ctl.exe" -WindowStyle Hidden -ArgumentList `
        'start', '-D', "$pg\data", '-o', '"-p 54329"', '-l', "$pg\pg.log"
    for ($i = 0; $i -lt 20 -and -not (Test-Port 54329); $i++) { Start-Sleep 1 }
    if (-not (Test-Port 54329)) { throw "PostgreSQL no arrancó. Revisa $pg\pg.log" }
    Write-Host 'PostgreSQL iniciado.'
}

# 2. Servidor
if (Test-Port 8080) {
    Write-Host 'El servidor ya está funcionando.'
} else {
    Start-Process powershell -WorkingDirectory "$root\backend" -ArgumentList `
        '-NoExit', '-Command', '$Host.UI.RawUI.WindowTitle = ''Ally servidor''; dart run bin/server.dart'
    for ($i = 0; $i -lt 90 -and -not (Test-Port 8080); $i++) { Start-Sleep 1 }
    Write-Host 'Servidor iniciado en http://localhost:8080'
}

# 3. Túnel público (la dirección es fija para tu cuenta de ngrok)
if (Get-Process ngrok -ErrorAction SilentlyContinue) {
    Write-Host 'ngrok ya está funcionando.'
} else {
    Start-Process ngrok -ArgumentList 'http', '8080'
    Write-Host 'ngrok iniciado.'
}

Write-Host ''
Write-Host 'Listo: https://connately-textbookish-dewitt.ngrok-free.dev/api/health'
