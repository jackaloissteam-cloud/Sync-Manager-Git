# =====================================================================
#  Sync Manager Git v2.2 - gemeinsame Funktionen
#  Sicherheit: PAT wird niemals in .git/config geschrieben.
# =====================================================================

Set-StrictMode -Version Latest

function Get-GhToolsConfig {
    $cfgDir    = Join-Path $env:USERPROFILE ".gh_tools"
    $tokenFile = Join-Path $cfgDir "token.dat"
    $cfgFile   = Join-Path $cfgDir "config.json"

    if (-not (Test-Path $tokenFile) -or -not (Test-Path $cfgFile)) {
        throw "Setup fehlt. Bitte zuerst gh-setup.ps1 ausfuehren."
    }

    $cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace([string]$cfg.user)) {
        throw "GitHub user fehlt in config.json."
    }
    if ([string]::IsNullOrWhiteSpace([string]$cfg.base_path)) {
        throw "base_path fehlt in config.json."
    }

    return [pscustomobject]@{
        User      = [string]$cfg.user
        BasePath  = [string]$cfg.base_path
        TokenFile = $tokenFile
    }
}

function Get-GhToolsToken {
    param([Parameter(Mandatory)][string]$TokenFile)

    $sec  = Get-Content $TokenFile | ConvertTo-SecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null
    }
}

function New-GhApiHeaders {
    param([Parameter(Mandatory)][string]$Token)

    return @{
        Authorization = "Bearer $Token"
        "User-Agent"  = "sync-manager-git-v2"
        Accept        = "application/vnd.github+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
}

function New-GitAskPassFile {
    $path = Join-Path $env:TEMP ("gh-tools-askpass-{0}-{1}.cmd" -f $PID, ([guid]::NewGuid().ToString("N")))
    @'
@echo off
set "PROMPT=%~1"
echo %PROMPT% | findstr /I "username" >nul
if %ERRORLEVEL%==0 (
  echo %GH_GIT_USER%
) else (
  echo %GH_GIT_TOKEN%
)
'@ | Set-Content -Path $path -Encoding ASCII
    return $path
}

function Invoke-GitAuthenticated {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$User,
        [Parameter(Mandatory)][string]$Token,
        [string]$WorkingDirectory = $null
    )

    $askPass = New-GitAskPassFile
    $oldAsk  = $env:GIT_ASKPASS
    $oldTerm = $env:GIT_TERMINAL_PROMPT
    $oldUser = $env:GH_GIT_USER
    $oldTok  = $env:GH_GIT_TOKEN
    $pushed  = $false

    try {
        $env:GIT_ASKPASS         = $askPass
        $env:GIT_TERMINAL_PROMPT = "0"
        $env:GH_GIT_USER         = $User
        $env:GH_GIT_TOKEN        = $Token

        if ($WorkingDirectory) {
            Push-Location $WorkingDirectory
            $pushed = $true
        }

        & git @Arguments | ForEach-Object { Write-Host $_ }
        $code = $LASTEXITCODE
        return $code
    }
    finally {
        if ($pushed) { Pop-Location }
        $env:GIT_ASKPASS         = $oldAsk
        $env:GIT_TERMINAL_PROMPT = $oldTerm
        $env:GH_GIT_USER         = $oldUser
        $env:GH_GIT_TOKEN        = $oldTok
        Remove-Item $askPass -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-BaselineGitIgnore {
    param([Parameter(Mandatory)][string]$RepositoryPath)

    $file = Join-Path $RepositoryPath ".gitignore"
    if (Test-Path $file) { return $false }

    @'
# Sync Manager Git v2 - sichere Standard-Ausschluesse
.vs/
.idea/
node_modules/
dist/
build/
coverage/
__pycache__/
*.pyc
.venv/
venv/
.env
.env.*
!.env.example
*.log
*.tmp
*.bak
Thumbs.db
.DS_Store
'@ | Set-Content -Path $file -Encoding UTF8

    Write-Host "Standard-.gitignore angelegt." -ForegroundColor Yellow
    return $true
}

function Get-OriginSlug {
    param([string]$RemoteUrl)

    if ([string]::IsNullOrWhiteSpace($RemoteUrl)) { return $null }

    $u = $RemoteUrl.Trim()

    if ($u -match '^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ Owner = $Matches[1]; Repo = $Matches[2] }
    }
    if ($u -match '^https://[^@]+@github\.com/([^/]+)/([^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ Owner = $Matches[1]; Repo = $Matches[2] }
    }
    if ($u -match '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$') {
        return [pscustomobject]@{ Owner = $Matches[1]; Repo = $Matches[2] }
    }

    return $null
}