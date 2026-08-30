# =====================================================================
#  GitHub PUSH / EXPORT
#  Usage:
#    interaktiv:  .\gh-push.ps1
#    per Ordner:  .\gh-push.ps1 -Path "C:\Projekte\meinrepo"
#  Der Ordnername wird als Repo-Name verwendet, wenn -Path angegeben ist.
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
    Read-Host "Enter zum Schliessen"
    exit 1
}

$cfg   = Get-Content $CFG_FILE -Raw | ConvertFrom-Json
$USER  = $cfg.user
$BASE  = $cfg.base_path

# Token entschluesseln
$sec   = Get-Content $TOKEN_FILE | ConvertTo-SecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

Write-Host ""
Write-Host "=== GitHub PUSH ===" -ForegroundColor Cyan

# Pfad + Repo-Name bestimmen
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
    if ([string]::IsNullOrWhiteSpace($repo)) {
        Write-Host "Kein Repo-Name angegeben. Abbruch." -ForegroundColor Red
        Read-Host "Enter zum Schliessen"; exit 1
    }
    $localPath = Join-Path $BASE $repo
    if (-not (Test-Path $localPath)) {
        Write-Host "FEHLER: Ordner '$localPath' existiert nicht." -ForegroundColor Red
        Read-Host "Enter zum Schliessen"; exit 1
    }
}

# GitHub API Header
$headers = @{
    Authorization = "token $TOKEN"
    "User-Agent"  = "gh-tools"
    Accept        = "application/vnd.github+json"
}

# Existiert das Repo?
$repoUrl = "https://api.github.com/repos/$USER/$repo"
try {
    Invoke-RestMethod -Uri $repoUrl -Headers $headers -Method Get | Out-Null
    Write-Host "Repo '$USER/$repo' existiert bereits auf GitHub." -ForegroundColor Green
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "Repo '$USER/$repo' existiert noch nicht. Wird PRIVAT angelegt..." -ForegroundColor Yellow
        $body = @{ name = $repo; private = $true; auto_init = $false } | ConvertTo-Json
        Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Repo angelegt." -ForegroundColor Green
    } else {
        Write-Host "FEHLER beim API-Aufruf: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Enter zum Schliessen"; exit 1
    }
}

Set-Location $localPath

$remoteHttps = "https://$USER`:$TOKEN@github.com/$USER/$repo.git"
$remotePub   = "https://github.com/$USER/$repo.git"

if (-not (Test-Path (Join-Path $localPath ".git"))) {
    Write-Host "Kein Git-Repo. Initialisiere..." -ForegroundColor Yellow
    git init | Out-Null
    git branch -M main
    git remote add origin $remoteHttps
} else {
    $existing = git remote 2>$null
    if ($existing -match "origin") {
        git remote set-url origin $remoteHttps | Out-Null
    } else {
        git remote add origin $remoteHttps | Out-Null
    }
    $cur = git rev-parse --abbrev-ref HEAD 2>$null
    if ($cur -eq "HEAD" -or [string]::IsNullOrWhiteSpace($cur)) {
        git checkout -b main 2>$null | Out-Null
    }
}

git add -A
$hasChanges = (git status --porcelain)
if ($hasChanges) {
    $ts  = Get-Date -Format "yyyy-MM-dd HH:mm"
    $msg = "Auto commit $ts"
    git commit -m "$msg" | Out-Null
    Write-Host "Commit: $msg" -ForegroundColor Green
} else {
    Write-Host "Keine Aenderungen zum Committen." -ForegroundColor Yellow
}

Write-Host "Pushe nach $remotePub ..." -ForegroundColor Cyan
git push -u origin main
$pushCode = $LASTEXITCODE
git remote set-url origin $remotePub | Out-Null

if ($pushCode -ne 0) {
    Write-Host "Push fehlgeschlagen." -ForegroundColor Red
    Read-Host "Enter zum Schliessen"; exit 1
}

Write-Host ""
Write-Host "Fertig! $USER/$repo aktualisiert." -ForegroundColor Green
Write-Host "URL: https://github.com/$USER/$repo"

# Bei per-Ordner-Aufruf kurz anzeigen und dann automatisch schliessen
if ($Path) {
    Write-Host ""
    Start-Sleep -Seconds 3
} else {
    Read-Host "Enter zum Schliessen"
}
