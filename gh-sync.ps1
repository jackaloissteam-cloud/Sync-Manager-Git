# =====================================================================
#  GitHub SYNC (Pull + Push)
#  Usage:
#    interaktiv:  .\gh-sync.ps1
#    per Ordner:  .\gh-sync.ps1 -Path "C:\Projekte\meinrepo"
# =====================================================================

param(
    [string]$Path = $null
)

$ErrorActionPreference = "Stop"

$CFG_DIR    = Join-Path $env:USERPROFILE ".gh_tools"
$TOKEN_FILE = Join-Path $CFG_DIR "token.dat"
$CFG_FILE   = Join-Path $CFG_DIR "config.json"

if (-not (Test-Path $TOKEN_FILE) -or -not (Test-Path $CFG_FILE)) {
    Write-Host "FEHLER: Setup fehlt. Bitte zuerst gh-setup.ps1 ausfuehren." -ForegroundColor Red
    Read-Host "Enter zum Schliessen"; exit 1
}

$cfg  = Get-Content $CFG_FILE -Raw | ConvertFrom-Json
$USER = $cfg.user
$BASE = $cfg.base_path

$sec   = Get-Content $TOKEN_FILE | ConvertTo-SecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

Write-Host ""
Write-Host "=== GitHub SYNC (Pull + Push) ===" -ForegroundColor Cyan

if ($Path) {
    $Path = $Path.TrimEnd('\','/')
    if (-not (Test-Path $Path)) {
        Write-Host "FEHLER: Ordner '$Path' existiert nicht." -ForegroundColor Red
        Read-Host "Enter zum Schliessen"; exit 1
    }
    $localPath = (Resolve-Path $Path).Path
    $repo      = Split-Path $localPath -Leaf
    Write-Host "Ordner:     $localPath"
    Write-Host "Repo-Name:  $repo (aus Ordnername)"
} else {
    $repo = Read-Host "Repo-Name"
    if ([string]::IsNullOrWhiteSpace($repo)) { Read-Host "Enter zum Schliessen"; exit 1 }
    $localPath = Join-Path $BASE $repo
}

if (-not (Test-Path (Join-Path $localPath ".git"))) {
    Write-Host "FEHLER: '$localPath' ist kein Git-Repo. Erst gh-import.ps1 oder gh-push.ps1 verwenden." -ForegroundColor Red
    Read-Host "Enter zum Schliessen"; exit 1
}

Set-Location $localPath

$remoteHttps = "https://$USER`:$TOKEN@github.com/$USER/$repo.git"
$remotePub   = "https://github.com/$USER/$repo.git"
git remote set-url origin $remoteHttps | Out-Null

$branch = git rev-parse --abbrev-ref HEAD 2>$null
if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq "HEAD") { $branch = "main" }

git add -A
$dirty = git status --porcelain
if ($dirty) {
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm"
    git commit -m "Auto commit $ts" | Out-Null
    Write-Host "Lokale Aenderungen committed." -ForegroundColor Green
}

Write-Host "Pull (rebase) ..." -ForegroundColor Cyan
git pull --rebase origin $branch
if ($LASTEXITCODE -ne 0) {
    Write-Host "Pull-Konflikt. Bitte manuell aufloesen." -ForegroundColor Red
    git remote set-url origin $remotePub | Out-Null
    Read-Host "Enter zum Schliessen"; exit 1
}

Write-Host "Push ..." -ForegroundColor Cyan
git push origin $branch
$pushCode = $LASTEXITCODE
git remote set-url origin $remotePub | Out-Null

if ($pushCode -ne 0) {
    Write-Host "Push fehlgeschlagen." -ForegroundColor Red
    Read-Host "Enter zum Schliessen"; exit 1
}

Write-Host ""
Write-Host "Sync abgeschlossen fuer $USER/$repo." -ForegroundColor Green

if ($Path) {
    Start-Sleep -Seconds 3
} else {
    Read-Host "Enter zum Schliessen"
}
