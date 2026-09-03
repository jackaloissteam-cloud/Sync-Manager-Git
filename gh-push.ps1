# =====================================================================
#  Sync Manager Git v2 - PUSH / EXPORT
#  - Neues GitHub-Repo bei Bedarf automatisch anlegen (privat)
#  - C:\Projekte ist Standardbasis
#  - PAT niemals in .git/config
# =====================================================================

param(
    [string]$Path = $null
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "gh-common.ps1")

function Pause-OnExit {
    param([string]$Text = "Enter zum Schliessen")
    Read-Host $Text | Out-Null
}

try {
    $cfg   = Get-GhToolsConfig
    $user  = $cfg.User
    $base  = $cfg.BasePath
    $token = Get-GhToolsToken -TokenFile $cfg.TokenFile
    $headers = New-GhApiHeaders -Token $token

    Write-Host ""
    Write-Host "=== Sync Manager Git v2 : PUSH ===" -ForegroundColor Cyan

    if ($Path) {
        $Path = $Path.TrimEnd('\','/')
        if (-not (Test-Path $Path)) { throw "Ordner '$Path' existiert nicht." }
        $localPath = (Resolve-Path $Path).Path
        $repo      = Split-Path $localPath -Leaf
    }
    else {
        Write-Host "Basis: $base" -ForegroundColor DarkGray
        $repo = Read-Host "Repo-/Ordnername"
        if ([string]::IsNullOrWhiteSpace($repo)) { throw "Kein Repo-Name angegeben." }
        $localPath = Join-Path $base $repo
        if (-not (Test-Path $localPath)) { throw "Ordner '$localPath' existiert nicht." }
    }

    Write-Host "Ordner : $localPath"
    Write-Host "GitHub : $user/$repo"

    $repoApi = "https://api.github.com/repos/$user/$repo"
    $exists = $false

    try {
        Invoke-RestMethod -Uri $repoApi -Headers $headers -Method Get | Out-Null
        $exists = $true
    }
    catch {
        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch {}
        if ($status -ne 404) { throw }
    }

    if (-not $exists) {
        Write-Host "GitHub-Repo existiert noch nicht -> lege PRIVATES Repo an..." -ForegroundColor Yellow
        $body = @{
            name      = $repo
            private   = $true
            auto_init = $false
        } | ConvertTo-Json

        Invoke-RestMethod `
            -Uri "https://api.github.com/user/repos" `
            -Headers $headers `
            -Method Post `
            -Body $body `
            -ContentType "application/json" | Out-Null

        Write-Host "Repo angelegt." -ForegroundColor Green
    }
    else {
        Write-Host "GitHub-Repo existiert bereits." -ForegroundColor Green
    }

    Push-Location $localPath
    try {
        [void](Ensure-BaselineGitIgnore -RepositoryPath $localPath)

        if (-not (Test-Path (Join-Path $localPath ".git"))) {
            Write-Host "Initialisiere lokales Git-Repo..." -ForegroundColor Yellow
            & git init
            if ($LASTEXITCODE -ne 0) { throw "git init fehlgeschlagen." }
            & git branch -M main
        }

        $remotePub = "https://github.com/$user/$repo.git"
        $remotes = @(& git remote 2>$null)

        if ($remotes -contains "origin") {
            & git remote set-url origin $remotePub
        }
        else {
            & git remote add origin $remotePub
        }

        $branch = (& git branch --show-current 2>$null).Trim()
        if ([string]::IsNullOrWhiteSpace($branch)) {
            $branch = "main"
            & git checkout -B main | Out-Null
        }

        & git add -A
        if ($LASTEXITCODE -ne 0) { throw "git add fehlgeschlagen." }

        $changes = @(& git status --short)
        if ($changes.Count -gt 0) {
            Write-Host ""
            Write-Host "Aenderungen:" -ForegroundColor Cyan
            $changes | ForEach-Object { Write-Host "  $_" }

            $msg = "Auto commit " + (Get-Date -Format "yyyy-MM-dd HH:mm")
            & git commit -m $msg
            if ($LASTEXITCODE -ne 0) { throw "git commit fehlgeschlagen." }
        }
        else {
            Write-Host "Keine neuen lokalen Aenderungen." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "Push -> $remotePub [$branch]" -ForegroundColor Cyan
        $code = Invoke-GitAuthenticated `
            -Arguments @("push","-u","origin",$branch) `
            -User $user `
            -Token $token `
            -WorkingDirectory $localPath

        if ($code -ne 0) { throw "Git push fehlgeschlagen (ExitCode $code)." }

        Write-Host ""
        Write-Host "FERTIG: $user/$repo" -ForegroundColor Green
        Write-Host "https://github.com/$user/$repo"
    }
    finally {
        Pop-Location
    }

    if ($Path) { Start-Sleep -Seconds 2 }
    else { Pause-OnExit }
}
catch {
    Write-Host ""
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Pause-OnExit
    exit 1
}