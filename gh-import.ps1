# =====================================================================
#  GitHub IMPORT (Clone)
#  - Fragt nach Repo-Name
#  - Prueft ob Repo auf GitHub existiert
#  - Klont nach C:\Projekte\<repo>
# =====================================================================

$ErrorActionPreference = "Stop"

$CFG_DIR    = Join-Path $env:USERPROFILE ".gh_tools"
$TOKEN_FILE = Join-Path $CFG_DIR "token.dat"
$CFG_FILE   = Join-Path $CFG_DIR "config.json"

if (-not (Test-Path $TOKEN_FILE) -or -not (Test-Path $CFG_FILE)) {
    Write-Host "FEHLER: Setup fehlt. Bitte zuerst gh-setup.ps1 ausfuehren." -ForegroundColor Red
    exit 1
}

$cfg  = Get-Content $CFG_FILE -Raw | ConvertFrom-Json
$USER = $cfg.user
$BASE = $cfg.base_path

$sec   = Get-Content $TOKEN_FILE | ConvertTo-SecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

Write-Host ""
Write-Host "=== GitHub IMPORT ===" -ForegroundColor Cyan
Write-Host "Ziel-Basispfad: $BASE"
$repo = Read-Host "Repo-Name"
if ([string]::IsNullOrWhiteSpace($repo)) {
    Write-Host "Kein Repo-Name angegeben. Abbruch." -ForegroundColor Red
    exit 1
}

$target = Join-Path $BASE $repo
if (Test-Path $target) {
    Write-Host "FEHLER: Zielordner '$target' existiert bereits." -ForegroundColor Red
    Write-Host "Tipp: gh-sync.ps1 verwenden fuer Update oder Ordner umbenennen." -ForegroundColor Yellow
    exit 1
}

# Repo-Existenz pruefen
$headers = @{
    Authorization = "token $TOKEN"
    "User-Agent"  = "gh-tools"
    Accept        = "application/vnd.github+json"
}
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$USER/$repo" -Headers $headers -Method Get | Out-Null
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "FEHLER: Repo '$USER/$repo' existiert nicht auf GitHub." -ForegroundColor Red
    } else {
        Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    }
    exit 1
}

if (-not (Test-Path $BASE)) {
    New-Item -ItemType Directory -Path $BASE | Out-Null
}

$cloneUrl = "https://$USER`:$TOKEN@github.com/$USER/$repo.git"
$pubUrl   = "https://github.com/$USER/$repo.git"

Write-Host "Klone nach $target ..." -ForegroundColor Cyan
git clone $cloneUrl $target
if ($LASTEXITCODE -ne 0) {
    Write-Host "Clone fehlgeschlagen." -ForegroundColor Red
    exit 1
}

# Remote-URL ohne Token neu setzen
Set-Location $target
git remote set-url origin $pubUrl | Out-Null

Write-Host ""
Write-Host "Fertig! Repo lokal unter: $target" -ForegroundColor Green
Write-Host ""
