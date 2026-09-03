# =====================================================================
#  Sync Manager Git v2 - IMPORT / CLONE
#  Standardziel: C:\Projekte\<Repo>
#  PAT niemals in Clone-URL oder .git/config
# =====================================================================

param(
    [string]$Repo  = $null,
    [string]$Owner = $null
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
    $headers = New-GhApiHeaders -Token $token

    if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = $user }

    Write-Host ""
    Write-Host "=== Sync Manager Git v2 : IMPORT ===" -ForegroundColor Cyan
    Write-Host "Zielbasis: $base"

    if ([string]::IsNullOrWhiteSpace($Repo)) {
        $Repo = Read-Host "Repo-Name"
    }
    if ([string]::IsNullOrWhiteSpace($Repo)) { throw "Kein Repo angegeben." }

    $target = Join-Path $base $Repo
    if (Test-Path $target) {
        throw "Zielordner '$target' existiert bereits. Fuer vorhandene Ordner SYNC verwenden."
    }

    try {
        Invoke-RestMethod `
            -Uri "https://api.github.com/repos/$Owner/$Repo" `
            -Headers $headers `
            -Method Get | Out-Null
    }
    catch {
        throw "GitHub-Repo '$Owner/$Repo' wurde nicht gefunden oder ist nicht zugaenglich."
    }

    if (-not (Test-Path $base)) {
        New-Item -ItemType Directory -Path $base | Out-Null
    }

    $cloneUrl = "https://github.com/$Owner/$Repo.git"

    Write-Host "Clone $Owner/$Repo -> $target" -ForegroundColor Cyan
    $code = Invoke-GitAuthenticated `
        -Arguments @("clone",$cloneUrl,$target) `
        -User $user `
        -Token $token

    if ($code -ne 0) { throw "Clone fehlgeschlagen (ExitCode $code)." }

    Push-Location $target
    try {
        & git remote set-url origin $cloneUrl
    }
    finally {
        Pop-Location
    }

    Write-Host ""
    Write-Host "IMPORT OK: $target" -ForegroundColor Green

    if ($PSBoundParameters.ContainsKey("Repo")) {
        Start-Sleep -Seconds 2
    }
    else {
        Pause-OnExit
    }
}
catch {
    Write-Host ""
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    Pause-OnExit
    exit 1
}