# =====================================================================
#  Rechtsklick-Installer
#  - Legt "Senden an"-Shortcuts (SendTo) an
#  - Registriert Kontextmenue-Eintraege in HKCU (kein Admin noetig):
#      Rechtsklick auf Ordner:            "GitHub Push"  / "GitHub Sync"
#      Rechtsklick auf Ordner-Hintergrund:"GitHub Push (dieser Ordner)"
# =====================================================================

$ErrorActionPreference = "Stop"

# Skript-Ordner = wo die gh-*.ps1 liegen
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PushPs1   = Join-Path $ScriptDir "gh-push.ps1"
$SyncPs1   = Join-Path $ScriptDir "gh-sync.ps1"

if (-not (Test-Path $PushPs1) -or -not (Test-Path $SyncPs1)) {
    Write-Host "FEHLER: gh-push.ps1 oder gh-sync.ps1 nicht im Ordner '$ScriptDir' gefunden." -ForegroundColor Red
    Read-Host "Enter zum Schliessen"; exit 1
}

Write-Host ""
Write-Host "=== Rechtsklick-Installer ===" -ForegroundColor Cyan
Write-Host "Script-Ordner: $ScriptDir"
Write-Host ""

# --- 1) "Senden an"-Shortcuts ---
$SendTo   = [Environment]::GetFolderPath('SendTo')
$icon     = "$env:SystemRoot\System32\shell32.dll"
$shell    = New-Object -ComObject WScript.Shell

function New-SendToLink($name, $scriptPath, $iconIdx) {
    $lnk = Join-Path $SendTo "$name.lnk"
    if (Test-Path $lnk) { Remove-Item $lnk -Force }
    $s = $shell.CreateShortcut($lnk)
    $s.TargetPath = "powershell.exe"
    $s.Arguments  = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Path"
    $s.WorkingDirectory = $ScriptDir
    $s.IconLocation = "$icon,$iconIdx"
    $s.Description  = $name
    $s.Save()
    Write-Host "  + SendTo: $name" -ForegroundColor Green
}

Write-Host "1) 'Senden an'-Shortcuts anlegen..."
New-SendToLink "GitHub Push"  $PushPs1 43   # Upload-Icon
New-SendToLink "GitHub Sync"  $SyncPs1 238  # Sync-Icon
Write-Host ""

# --- 2) HKCU Kontextmenue ---
# Kein Admin noetig, wirkt nur fuer den aktuellen User.
function Register-DirVerb($rootPath, $verbKey, $label, $scriptPath, $useV, $iconIdx) {
    # rootPath z.B. "HKCU:\Software\Classes\Directory\shell\GhPush"
    New-Item -Path $rootPath -Force | Out-Null
    Set-ItemProperty -Path $rootPath -Name '(default)' -Value $label
    Set-ItemProperty -Path $rootPath -Name 'Icon'      -Value "$icon,$iconIdx"

    $cmdKey = Join-Path $rootPath 'command'
    New-Item -Path $cmdKey -Force | Out-Null
    $target = if ($useV) { '"%V"' } else { '"%1"' }
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Path $target"
    Set-ItemProperty -Path $cmdKey -Name '(default)' -Value $cmd
    Write-Host "  + $rootPath -> $label" -ForegroundColor Green
}

Write-Host "2) Kontextmenue-Eintraege registrieren (HKCU)..."

# Rechtsklick AUF einen Ordner -> %1 = Ordnerpfad
Register-DirVerb "HKCU:\Software\Classes\Directory\shell\GhPush" "GhPush" "GitHub Push"  $PushPs1 $false 43
Register-DirVerb "HKCU:\Software\Classes\Directory\shell\GhSync" "GhSync" "GitHub Sync"  $SyncPs1 $false 238

# Rechtsklick auf Ordner-HINTERGRUND (in einem geoeffneten Ordner) -> %V = aktueller Ordner
Register-DirVerb "HKCU:\Software\Classes\Directory\Background\shell\GhPush" "GhPush" "GitHub Push (dieser Ordner)" $PushPs1 $true 43
Register-DirVerb "HKCU:\Software\Classes\Directory\Background\shell\GhSync" "GhSync" "GitHub Sync (dieser Ordner)" $SyncPs1 $true 238

Write-Host ""
Write-Host "Installation abgeschlossen." -ForegroundColor Green
Write-Host ""
Write-Host "So verwendest du es:" -ForegroundColor Yellow
Write-Host "  - Rechtsklick auf einen Ordner        -> 'GitHub Push' / 'GitHub Sync'"
Write-Host "  - Rechtsklick in einem geoeffneten Ordner (leere Flaeche) -> 'GitHub Push (dieser Ordner)'"
Write-Host "  - Oder: Rechtsklick auf Ordner -> 'Senden an' -> 'GitHub Push'"
Write-Host ""
Write-Host "Hinweis: In Windows 11 ggf. 'Weitere Optionen anzeigen' klicken." -ForegroundColor DarkYellow
Write-Host ""
Read-Host "Enter zum Schliessen"
