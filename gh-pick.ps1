# =====================================================================
#  Sync Manager Git v2 - GUI REPO MANAGER
#  - GitHub-Repos anzeigen / filtern
#  - Clone in separatem sichtbaren Prozess
#  - Sync in separatem sichtbaren Prozess
#  - Lokalen Ordner nach GitHub pushen
#  -> GUI friert bei Git-Operationen nicht mehr ein.
# =====================================================================

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

. (Join-Path $PSScriptRoot "gh-common.ps1")

try {
    $cfg   = Get-GhToolsConfig
    $USER  = $cfg.User
    $BASE  = $cfg.BasePath
    $TOKEN = Get-GhToolsToken -TokenFile $cfg.TokenFile
}
catch {
    [System.Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "Sync Manager Git v2",
        "OK",
        "Error"
    ) | Out-Null
    exit 1
}

$headers = New-GhApiHeaders -Token $TOKEN

function Get-AllRepos {
    $all  = @()
    $page = 1

    while ($true) {
        $url = "https://api.github.com/user/repos?per_page=100&page=$page&sort=pushed&affiliation=owner,collaborator,organization_member"
        $r = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        if (-not $r -or $r.Count -eq 0) { break }

        $all += $r
        if ($r.Count -lt 100) { break }
        $page++
    }

    return $all
}

function Quote-Arg([string]$Value) {
    return '"' + $Value.Replace('"','\"') + '"'
}

function Start-ToolProcess {
    param(
        [Parameter(Mandatory)][string]$ScriptName,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        throw "Script fehlt: $scriptPath"
    }

    $parts = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Quote-Arg $scriptPath)
    )

    foreach ($arg in $Arguments) {
        if ($arg.StartsWith("-")) {
            $parts += $arg
        }
        else {
            $parts += (Quote-Arg $arg)
        }
    }

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList ($parts -join " ") `
        -WorkingDirectory $PSScriptRoot | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Sync Manager Git v2  -  $USER"
$form.Size = New-Object System.Drawing.Size(1020, 680)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(15,18,15)
$form.ForeColor = [System.Drawing.Color]::FromArgb(235,235,235)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = "SYNC MANAGER GIT v2"
$title.Location = New-Object System.Drawing.Point(18,12)
$title.Size = New-Object System.Drawing.Size(500,28)
$title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(255,180,60)
$form.Controls.Add($title)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = "GitHub: $USER     Lokale Basis: $BASE"
$subtitle.Location = New-Object System.Drawing.Point(20,42)
$subtitle.Size = New-Object System.Drawing.Size(750,20)
$subtitle.ForeColor = [System.Drawing.Color]::FromArgb(170,170,170)
$form.Controls.Add($subtitle)

$status = New-Object System.Windows.Forms.Label
$status.Text = "Bereit"
$status.Location = New-Object System.Drawing.Point(20,605)
$status.Size = New-Object System.Drawing.Size(950,24)
$status.ForeColor = [System.Drawing.Color]::FromArgb(170,200,170)
$form.Controls.Add($status)

$filterLabel = New-Object System.Windows.Forms.Label
$filterLabel.Text = "Suche:"
$filterLabel.Location = New-Object System.Drawing.Point(20,77)
$filterLabel.Size = New-Object System.Drawing.Size(55,22)
$form.Controls.Add($filterLabel)

$filter = New-Object System.Windows.Forms.TextBox
$filter.Location = New-Object System.Drawing.Point(78,74)
$filter.Size = New-Object System.Drawing.Size(500,26)
$filter.BackColor = [System.Drawing.Color]::FromArgb(28,32,28)
$filter.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($filter)

$onlyPrivate = New-Object System.Windows.Forms.CheckBox
$onlyPrivate.Text = "nur privat"
$onlyPrivate.Location = New-Object System.Drawing.Point(600,75)
$onlyPrivate.Size = New-Object System.Drawing.Size(100,24)
$form.Controls.Add($onlyPrivate)

$onlyOwned = New-Object System.Windows.Forms.CheckBox
$onlyOwned.Text = "nur eigene"
$onlyOwned.Location = New-Object System.Drawing.Point(710,75)
$onlyOwned.Size = New-Object System.Drawing.Size(110,24)
$onlyOwned.Checked = $true
$form.Controls.Add($onlyOwned)

$lv = New-Object System.Windows.Forms.ListView
$lv.Location = New-Object System.Drawing.Point(20,112)
$lv.Size = New-Object System.Drawing.Size(965,420)
$lv.View = "Details"
$lv.FullRowSelect = $true
$lv.MultiSelect = $false
$lv.GridLines = $false
$lv.BackColor = [System.Drawing.Color]::FromArgb(20,23,20)
$lv.ForeColor = [System.Drawing.Color]::FromArgb(235,235,235)
$lv.Font = New-Object System.Drawing.Font("Consolas", 9.5)

[void]$lv.Columns.Add("Repo", 260)
[void]$lv.Columns.Add("Sichtbarkeit", 95)
[void]$lv.Columns.Add("Sprache", 105)
[void]$lv.Columns.Add("Letzter Push", 145)
[void]$lv.Columns.Add("Beschreibung", 340)
$form.Controls.Add($lv)

function New-Button($Text, $X, $Width, $Primary = $false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Location = New-Object System.Drawing.Point($X,548)
    $b.Size = New-Object System.Drawing.Size($Width,40)
    $b.FlatStyle = "Flat"

    if ($Primary) {
        $b.BackColor = [System.Drawing.Color]::FromArgb(255,176,0)
        $b.ForeColor = [System.Drawing.Color]::FromArgb(20,20,20)
        $b.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    }
    else {
        $b.BackColor = [System.Drawing.Color]::FromArgb(28,32,28)
        $b.ForeColor = [System.Drawing.Color]::FromArgb(235,235,235)
    }
    return $b
}

$btnClone = New-Button "Clone -> C:\Projekte"       20  175 $true
$btnSync  = New-Button "Sync ausgewaehltes Repo"    205 185
$btnPush  = New-Button "Lokalen Ordner -> GitHub"   400 190 $true
$btnOpen  = New-Button "GitHub oeffnen"             600 135
$btnReload= New-Button "Neu laden"                  745 105
$btnClose = New-Button "Schliessen"                 860 125

$form.Controls.AddRange(@($btnClone,$btnSync,$btnPush,$btnOpen,$btnReload,$btnClose))

$script:allRepos = @()

function Get-SelectedRepo {
    if ($lv.SelectedItems.Count -eq 0) { return $null }
    return $lv.SelectedItems[0].Tag
}

function Refresh-List {
    $lv.BeginUpdate()
    try {
        $lv.Items.Clear()
        $q = $filter.Text.Trim().ToLower()
        $count = 0

        foreach ($r in $script:allRepos) {
            if ($onlyPrivate.Checked -and -not $r.private) { continue }
            if ($onlyOwned.Checked -and $r.owner.login -ne $USER) { continue }

            $full = "$($r.owner.login)/$($r.name)".ToLower()
            $descText = [string]$r.description

            if ($q -ne "" -and
                $full -notlike "*$q*" -and
                $descText.ToLower() -notlike "*$q*") {
                continue
            }

            $item = New-Object System.Windows.Forms.ListViewItem($r.name)
            [void]$item.SubItems.Add($(if ($r.private) { "private" } else { "public" }))
            [void]$item.SubItems.Add([string]$r.language)

            try {
                $d = ([datetime]$r.pushed_at).ToString("yyyy-MM-dd HH:mm")
            }
            catch {
                $d = ""
            }

            [void]$item.SubItems.Add($d)

            if ($descText.Length -gt 110) {
                $descText = $descText.Substring(0,107) + "..."
            }
            [void]$item.SubItems.Add($descText)

            $item.Tag = $r
            if ($r.private) {
                $item.ForeColor = [System.Drawing.Color]::FromArgb(255,205,100)
            }

            [void]$lv.Items.Add($item)
            $count++
        }

        if ($lv.Items.Count -gt 0) {
            $lv.Items[0].Selected = $true
            $lv.Items[0].Focused  = $true
        }

        $status.Text = "$count / $($script:allRepos.Count) Repos angezeigt"
    }
    finally {
        $lv.EndUpdate()
    }
}

function Load-Repos {
    $status.Text = "Lade GitHub-Repos..."
    $form.Refresh()

    try {
        $script:allRepos = @(Get-AllRepos)
        Refresh-List
    }
    catch {
        $status.Text = "Fehler beim Laden"
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Sync Manager Git v2",
            "OK",
            "Error"
        ) | Out-Null
    }
}

$filter.Add_TextChanged({ Refresh-List })
$onlyPrivate.Add_CheckedChanged({ Refresh-List })
$onlyOwned.Add_CheckedChanged({ Refresh-List })
$btnReload.Add_Click({ Load-Repos })
$btnClose.Add_Click({ $form.Close() })

$btnOpen.Add_Click({
    $r = Get-SelectedRepo
    if ($r) { Start-Process $r.html_url }
})

$btnClone.Add_Click({
    $r = Get-SelectedRepo
    if (-not $r) { return }

    $target = Join-Path $BASE $r.name
    if (Test-Path $target) {
        [System.Windows.Forms.MessageBox]::Show(
            "Der Ordner existiert bereits:`n$target`n`nBitte SYNC verwenden.",
            "Sync Manager Git v2",
            "OK",
            "Warning"
        ) | Out-Null
        return
    }

    try {
        Start-ToolProcess `
            -ScriptName "gh-import.ps1" `
            -Arguments @("-Repo",[string]$r.name,"-Owner",[string]$r.owner.login)

        $status.Text = "Clone gestartet: $($r.owner.login)/$($r.name) - Ausgabe im PowerShell-Fenster"
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

$btnSync.Add_Click({
    $r = Get-SelectedRepo
    if (-not $r) { return }

    $target = Join-Path $BASE $r.name
    if (-not (Test-Path (Join-Path $target ".git"))) {
        [System.Windows.Forms.MessageBox]::Show(
            "$target ist lokal kein Git-Repo.`nBitte zuerst Clone verwenden.",
            "Sync Manager Git v2",
            "OK",
            "Warning"
        ) | Out-Null
        return
    }

    try {
        Start-ToolProcess `
            -ScriptName "gh-sync.ps1" `
            -Arguments @("-Path",$target)

        $status.Text = "Sync gestartet: $target - Live-Ausgabe im PowerShell-Fenster"
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

$btnPush.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "Lokalen Projektordner auswaehlen, der nach GitHub soll"
    if (Test-Path $BASE) { $dlg.SelectedPath = $BASE }

    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return
    }

    try {
        Start-ToolProcess `
            -ScriptName "gh-push.ps1" `
            -Arguments @("-Path",$dlg.SelectedPath)

        $status.Text = "Push gestartet: $($dlg.SelectedPath) - Live-Ausgabe im PowerShell-Fenster"
    }
    catch {
        $status.Text = $_.Exception.Message
    }
})

$lv.Add_DoubleClick({ $btnClone.PerformClick() })

$form.Add_Shown({ Load-Repos })
[void]$form.ShowDialog()