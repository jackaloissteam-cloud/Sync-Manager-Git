# =====================================================================
#  GitHub Setup - Personal Access Token sicher speichern (Windows DPAPI)
#  Einmal ausfuehren. Token wird verschluesselt in %USERPROFILE%\.gh_tools abgelegt.
# =====================================================================

$ErrorActionPreference = "Stop"

$GH_USER   = "jackaloissteam-cloud"
$BASE_PATH = "C:\Projekte"
$CFG_DIR   = Join-Path $env:USERPROFILE ".gh_tools"
$TOKEN_FILE= Join-Path $CFG_DIR "token.dat"
$CFG_FILE  = Join-Path $CFG_DIR "config.json"

Write-Host ""
Write-Host "=== GitHub Tools - Setup ===" -ForegroundColor Cyan
Write-Host "GitHub User : $GH_USER"
Write-Host "Basis-Pfad  : $BASE_PATH"
Write-Host ""

if (-not (Test-Path $CFG_DIR)) {
    New-Item -ItemType Directory -Path $CFG_DIR | Out-Null
}
if (-not (Test-Path $BASE_PATH)) {
    New-Item -ItemType Directory -Path $BASE_PATH | Out-Null
    Write-Host "Ordner $BASE_PATH erstellt." -ForegroundColor Yellow
}

# Git pruefen
try {
    $gitVer = git --version
    Write-Host "Git gefunden: $gitVer" -ForegroundColor Green
} catch {
    Write-Host "FEHLER: Git ist nicht installiert. Bitte installieren: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Bitte gib deinen GitHub Personal Access Token (PAT) ein." -ForegroundColor Yellow
Write-Host "Erstellen unter: https://github.com/settings/tokens (Scope: 'repo' benoetigt)"
$secure = Read-Host "Token" -AsSecureString

# Verschluesselt speichern (DPAPI, nur der aktuelle Windows-User kann entschluesseln)
$secure | ConvertFrom-SecureString | Set-Content -Path $TOKEN_FILE -Encoding UTF8

# Config schreiben
$cfg = @{
    user      = $GH_USER
    base_path = $BASE_PATH
} | ConvertTo-Json
Set-Content -Path $CFG_FILE -Value $cfg -Encoding UTF8

# Git global identity abfragen (falls leer)
$gitName  = (git config --global user.name)  2>$null
$gitEmail = (git config --global user.email) 2>$null
if ([string]::IsNullOrWhiteSpace($gitName)) {
    $n = Read-Host "Git user.name (z.B. Vorname Nachname)"
    git config --global user.name "$n"
}
if ([string]::IsNullOrWhiteSpace($gitEmail)) {
    $e = Read-Host "Git user.email"
    git config --global user.email "$e"
}

Write-Host ""
Write-Host "Setup abgeschlossen." -ForegroundColor Green
Write-Host "Token gespeichert unter: $TOKEN_FILE (verschluesselt, DPAPI)"
Write-Host ""
