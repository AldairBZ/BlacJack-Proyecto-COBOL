Set-Location $PSScriptRoot

$backendSource = "backend\blackjack.cob.cbl"
$backendExe = "backend\bin\blackjack_runtime.exe"
$pythonExe = ".\.venv\Scripts\python.exe"
$gnuCobolRoot = "C:\GnuCOBOL"

if (Test-Path $gnuCobolRoot) {
    $env:COB_CONFIG_DIR = Join-Path $gnuCobolRoot "config"
    $env:COB_COPY_DIR = Join-Path $gnuCobolRoot "copy"
    $env:COB_LIBRARY_PATH = Join-Path $gnuCobolRoot "extras"
    $env:COB_CFLAGS = "-I`"$gnuCobolRoot\include`" $env:COB_CFLAGS"
    $env:COB_LDFLAGS = "-L`"$gnuCobolRoot\lib`" $env:COB_LDFLAGS"
    if ($env:Path -notlike "*$gnuCobolRoot\bin*") {
        $env:Path = "$gnuCobolRoot\bin;$env:Path"
    }
}

if (!(Test-Path $pythonExe)) {
    Write-Host "No se encontró el venv en .venv."
    Write-Host "Ejecuta estos comandos desde la raíz del proyecto y vuelve a intentar:"
    Write-Host "  py -3 -m venv .venv"
    Write-Host "  .\.venv\Scripts\python.exe -m pip install -r requirements.txt"
    Write-Host "  powershell -NoProfile -ExecutionPolicy Bypass -File .\run_blackjack.ps1"
    exit 1
}

if (!(Test-Path "backend\bin")) {
    New-Item -ItemType Directory -Path "backend\bin" | Out-Null
}

Write-Host "Compilando backend COBOL..."
cobc -x -free $backendSource -o $backendExe
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error compilando COBOL. Verifica que GnuCOBOL (cobc) esté instalado."
    exit 1
}

if (!(Test-Path "DATA")) {
    New-Item -ItemType Directory -Path "DATA" | Out-Null
}

if (!(Test-Path "DATA\BRIDGE.DAT")) {
    (" " * 220) | Set-Content "DATA\BRIDGE.DAT"
}

if (!(Test-Path "DATA\RANKING.TXT")) {
    "" | Set-Content "DATA\RANKING.TXT"
}

Write-Host "Iniciando frontend Python..."
& $pythonExe "Frontend\app.py"
