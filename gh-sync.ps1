# =====================================================================
#  Sync Manager Git v2 - SYNC
#  Reihenfolge: add -> commit -> pull --rebase -> push
#  PAT niemals in .git/config
# =====================================================================

param(
    [string]$Path = $null
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "gh-common.ps1")

function Pause-OnExit {
    Read-Host "Enter zum Schliessen" | Out-Null
}

try {
    $cfg   = Get-GhToolsConfig
    $user  = $cfg.User
    $base  = $cfg.BasePath
    $token = Get-GhToolsToken -TokenFile $cfg.TokenFile

    Write-Host ""
    Write-Host "=== Sync Manager Git v2 : SYNC ===" -ForegroundColor Cyan

    if ($Path) {
        $Path = $Path.TrimEnd('\','/')
        if (-not (Test-Path $Path)) { throw "Ordner '$Path' existiert nicht." }
        $localPath = (Resolve-Path $Path).Path
    }
    else {
        Write-Host "Basis: $base" -ForegroundColor DarkGray
        $repoName = Read-Host "Repo-/Ordnername"
        if ([string]::IsNullOrWhiteSpace($repoName)) { throw "Kein Repo angegeben." }
        $localPath = Join-Path $base $repoName
    }

    if (-not (Test-Path (Join-Path $localPath ".git"))) {
        throw "'$localPath' ist kein Git-Repo. Erst Push/Import verwenden."
    }

    Push-Location $localPath
    try {
        [void](Ensure-BaselineGitIgnore -RepositoryPath $localPath)

        $originUrl = (& git remote get-url origin 2>$null | Select-Object -First 1)
        $slug = Get-OriginSlug -RemoteUrl $originUrl

        if ($null -eq $slug) {
            $repoName = Split-Path $localPath -Leaf
            $owner = $user
        }
        else {
            $repoName = $slug.Repo
            $owner    = $slug.Owner
        }

        $remotePub = "https://github.com/$owner/$repoName.git"
        & git remote set-url origin $remotePub

        $branch = (& git branch --show-current 2>$null).Trim()
        if ([string]::IsNullOrWhiteSpace($branch)) { $branch = "main" }

        Write-Host "Ordner : $localPath"
        Write-Host "Remote : $owner/$repoName"
        Write-Host "Branch : $branch"

        & git add -A
        if ($LASTEXITCODE -ne 0) { throw "git add fehlgeschlagen." }

        $changes = @(& git status --short)
        if ($changes.Count -gt 0) {
            Write-Host ""
            Write-Host "Lokale Aenderungen:" -ForegroundColor Cyan
            $changes | ForEach-Object { Write-Host "  $_" }

            $msg = "Auto commit " + (Get-Date -Format "yyyy-MM-dd HH:mm")
            & git commit -m $msg
            if ($LASTEXITCODE -ne 0) { throw "git commit fehlgeschlagen." }
        }
        else {
            Write-Host "Keine lokalen Aenderungen zum Committen." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "PULL --rebase..." -ForegroundColor Cyan
        $pullCode = Invoke-GitAuthenticated `
            -Arguments @("pull","--rebase","origin",$branch) `
            -User $user `
            -Token $token `
            -WorkingDirectory $localPath

        if ($pullCode -ne 0) {
            throw "Pull/Rebase fehlgeschlagen. Bei Konflikten: git status pruefen."
        }

        Write-Host ""
        Write-Host "PUSH..." -ForegroundColor Cyan
        $pushCode = Invoke-GitAuthenticated `
            -Arguments @("push","origin",$branch) `
            -User $user `
            -Token $token `
            -WorkingDirectory $localPath

        if ($pushCode -ne 0) { throw "Push fehlgeschlagen (ExitCode $pushCode)." }

        Write-Host ""
        Write-Host "SYNC OK: $owner/$repoName" -ForegroundColor Green
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