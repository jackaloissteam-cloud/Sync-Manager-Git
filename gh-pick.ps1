# =====================================================================
#  GitHub REPO PICKER (WinForms GUI)
#  - Zeigt alle deine GitHub-Repos in einer Liste (Suche, privat/oeffentlich,
#    Sprache, letztes Update).
#  - "Clone selected" -> git clone nach C:\Projekte\<repo>
#  - "Open on GitHub" -> oeffnet Repo-Seite im Browser
#  - Wenn Ziel-Ordner schon existiert: Sync-Option angeboten.
# =====================================================================

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$CFG_DIR    = Join-Path $env:USERPROFILE ".gh_tools"
$TOKEN_FILE = Join-Path $CFG_DIR "token.dat"
$CFG_FILE   = Join-Path $CFG_DIR "config.json"

if (-not (Test-Path $TOKEN_FILE) -or -not (Test-Path $CFG_FILE)) {
    [System.Windows.Forms.MessageBox]::Show("Setup fehlt.`nBitte zuerst gh-setup.bat ausfuehren.","GitHub Repo Picker",'OK','Error') | Out-Null
    exit 1
}

$cfg  = Get-Content $CFG_FILE -Raw | ConvertFrom-Json
$USER = $cfg.user
$BASE = $cfg.base_path

# Token
$sec   = Get-Content $TOKEN_FILE | ConvertTo-SecureString
$bstr  = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$TOKEN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) | Out-Null

$headers = @{
    Authorization = "token $TOKEN"
    "User-Agent"  = "gh-tools"
    Accept        = "application/vnd.github+json"
}

# --- Repos laden (paginierend, sortiert nach letztem Push) ---
function Get-AllRepos {
    $all  = @()
    $page = 1
    while ($true) {
        $u = "https://api.github.com/user/repos?per_page=100&page=$page&sort=pushed&affiliation=owner,collaborator,organization_member"
        $r = Invoke-RestMethod -Uri $u -Headers $headers -Method Get
        if (-not $r -or $r.Count -eq 0) { break }
        $all += $r
        if ($r.Count -lt 100) { break }
        $page++
    }
    return $all
}

# --- Form aufbauen ---
$form              = New-Object System.Windows.Forms.Form
$form.Text         = "GitHub Repo Picker  -  $USER"
$form.Size         = New-Object System.Drawing.Size(880, 620)
$form.StartPosition= 'CenterScreen'
$form.BackColor    = [System.Drawing.Color]::FromArgb(15,18,15)
$form.ForeColor    = [System.Drawing.Color]::FromArgb(230,230,230)
$form.Font         = New-Object System.Drawing.Font("Segoe UI", 9)

# Header
$lblTitle          = New-Object System.Windows.Forms.Label
$lblTitle.Text     = "Repos von $USER"
$lblTitle.Location = New-Object System.Drawing.Point(16,12)
$lblTitle.Size     = New-Object System.Drawing.Size(500,22)
$lblTitle.Font     = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor= [System.Drawing.Color]::FromArgb(255,180,60)
$form.Controls.Add($lblTitle)

$lblStatus         = New-Object System.Windows.Forms.Label
$lblStatus.Text    = "lade..."
$lblStatus.Location= New-Object System.Drawing.Point(16,40)
$lblStatus.Size    = New-Object System.Drawing.Size(820,18)
$lblStatus.ForeColor= [System.Drawing.Color]::FromArgb(160,160,160)
$form.Controls.Add($lblStatus)

# Suchfeld
$lblFilter         = New-Object System.Windows.Forms.Label
$lblFilter.Text    = "Filter:"
$lblFilter.Location= New-Object System.Drawing.Point(16,70)
$lblFilter.Size    = New-Object System.Drawing.Size(50,22)
$form.Controls.Add($lblFilter)

$txtFilter         = New-Object System.Windows.Forms.TextBox
$txtFilter.Location= New-Object System.Drawing.Point(66,68)
$txtFilter.Size    = New-Object System.Drawing.Size(500,22)
$txtFilter.BackColor= [System.Drawing.Color]::FromArgb(28,32,28)
$txtFilter.ForeColor= [System.Drawing.Color]::White
$txtFilter.BorderStyle = 'FixedSingle'
$form.Controls.Add($txtFilter)

$chkOnlyPrivate    = New-Object System.Windows.Forms.CheckBox
$chkOnlyPrivate.Text = "nur privat"
$chkOnlyPrivate.Location = New-Object System.Drawing.Point(580,68)
$chkOnlyPrivate.Size = New-Object System.Drawing.Size(90,22)
$chkOnlyPrivate.ForeColor = [System.Drawing.Color]::FromArgb(220,220,220)
$form.Controls.Add($chkOnlyPrivate)

$chkOwnedOnly      = New-Object System.Windows.Forms.CheckBox
$chkOwnedOnly.Text = "nur eigene"
$chkOwnedOnly.Location = New-Object System.Drawing.Point(680,68)
$chkOwnedOnly.Size = New-Object System.Drawing.Size(90,22)
$chkOwnedOnly.Checked = $true
$chkOwnedOnly.ForeColor = [System.Drawing.Color]::FromArgb(220,220,220)
$form.Controls.Add($chkOwnedOnly)

# ListView
$lv               = New-Object System.Windows.Forms.ListView
$lv.Location      = New-Object System.Drawing.Point(16,100)
$lv.Size          = New-Object System.Drawing.Size(840,410)
$lv.View          = 'Details'
$lv.FullRowSelect = $true
$lv.MultiSelect   = $false
$lv.GridLines     = $false
$lv.BackColor     = [System.Drawing.Color]::FromArgb(20,23,20)
$lv.ForeColor     = [System.Drawing.Color]::FromArgb(235,235,235)
$lv.Font          = New-Object System.Drawing.Font("Consolas", 9)
[void]$lv.Columns.Add("Repo", 260)
[void]$lv.Columns.Add("Sichtbarkeit", 90)
[void]$lv.Columns.Add("Sprache", 100)
[void]$lv.Columns.Add("Aktualisiert", 130)
[void]$lv.Columns.Add("Beschreibung", 240)
$form.Controls.Add($lv)

# Buttons
function New-Btn($text,$x,$w,$primary=$false) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Location = New-Object System.Drawing.Point($x,525)
    $b.Size = New-Object System.Drawing.Size($w,34)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderSize = 1
    if ($primary) {
        $b.BackColor = [System.Drawing.Color]::FromArgb(255,176,0)
        $b.ForeColor = [System.Drawing.Color]::FromArgb(20,20,20)
        $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(255,176,0)
        $b.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    } else {
        $b.BackColor = [System.Drawing.Color]::FromArgb(28,32,28)
        $b.ForeColor = [System.Drawing.Color]::FromArgb(230,230,230)
        $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70,74,70)
    }
    return $b
}

$btnClone    = New-Btn "Clone -> C:\Projekte" 16  200 $true
$btnSync     = New-Btn "Sync (falls schon lokal)" 226 180
$btnOpen     = New-Btn "Auf GitHub oeffnen" 416 150
$btnRefresh  = New-Btn "Neu laden" 576 100
$btnClose    = New-Btn "Schliessen" 686 100

$form.Controls.AddRange(@($btnClone,$btnSync,$btnOpen,$btnRefresh,$btnClose))

# --- Daten Handling ---
$script:allRepos = @()

function Refresh-List {
    $lv.BeginUpdate()
    $lv.Items.Clear()
    $q = $txtFilter.Text.Trim().ToLower()
    $count = 0
    foreach ($r in $script:allRepos) {
        if ($chkOnlyPrivate.Checked -and -not $r.private) { continue }
        if ($chkOwnedOnly.Checked   -and $r.owner.login  -ne $USER) { continue }
        $full = "$($r.owner.login)/$($r.name)".ToLower()
        if ($q -ne "" -and ($full -notlike "*$q*") -and (($r.description -as [string]).ToLower() -notlike "*$q*")) { continue }
        $it = New-Object System.Windows.Forms.ListViewItem($r.name)
        [void]$it.SubItems.Add($(if ($r.private) {"private"} else {"public"}))
        [void]$it.SubItems.Add([string]$r.language)
        try { $d = ([datetime]$r.pushed_at).ToString("yyyy-MM-dd HH:mm") } catch { $d = "" }
        [void]$it.SubItems.Add($d)
        $desc = [string]$r.description
        if ($desc.Length -gt 90) { $desc = $desc.Substring(0,87) + "..." }
        [void]$it.SubItems.Add($desc)
        $it.Tag = $r
        if ($r.private) { $it.ForeColor = [System.Drawing.Color]::FromArgb(255,200,90) }
        [void]$lv.Items.Add($it)
        $count++
    }
    if ($lv.Items.Count -gt 0) { $lv.Items[0].Selected = $true; $lv.Items[0].Focused = $true }
    $lv.EndUpdate()
    $lblStatus.Text = "$count / $($script:allRepos.Count) Repos angezeigt"
}

function Load-Repos {
    $lblStatus.Text = "lade Repos von GitHub..."
    $form.Refresh()
    try {
        $script:allRepos = Get-AllRepos
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Fehler beim Laden:`n$($_.Exception.Message)","GitHub Repo Picker",'OK','Error') | Out-Null
        return
    }
    Refresh-List
}

# Events
$txtFilter.Add_TextChanged({ Refresh-List })
$chkOnlyPrivate.Add_CheckedChanged({ Refresh-List })
$chkOwnedOnly.Add_CheckedChanged({ Refresh-List })
$btnRefresh.Add_Click({ Load-Repos })
$btnClose.Add_Click({ $form.Close() })

function Get-SelectedRepo {
    if ($lv.SelectedItems.Count -eq 0) { return $null }
    return $lv.SelectedItems[0].Tag
}

$btnOpen.Add_Click({
    $r = Get-SelectedRepo
    if ($r) { Start-Process $r.html_url }
})

$btnClone.Add_Click({
    $r = Get-SelectedRepo
    if (-not $r) { return }
    $owner = $r.owner.login
    $name  = $r.name
    $target= Join-Path $BASE $name
    if (Test-Path $target) {
        [System.Windows.Forms.MessageBox]::Show("Zielordner existiert bereits:`n$target`n`nBitte 'Sync' verwenden.","GitHub Repo Picker",'OK','Warning') | Out-Null
        return
    }
    if (-not (Test-Path $BASE)) { New-Item -ItemType Directory -Path $BASE | Out-Null }

    $lblStatus.Text = "clone $owner/$name ..."
    $form.Refresh()
    $urlAuth = "https://$USER`:$TOKEN@github.com/$owner/$name.git"
    $urlPub  = "https://github.com/$owner/$name.git"
    & git clone $urlAuth $target 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        [System.Windows.Forms.MessageBox]::Show("Clone fehlgeschlagen.","GitHub Repo Picker",'OK','Error') | Out-Null
        $lblStatus.Text = "clone fehlgeschlagen"
        return
    }
    Push-Location $target
    & git remote set-url origin $urlPub 2>&1 | Out-Null
    Pop-Location

    $lblStatus.Text = "clone OK -> $target"
    # Explorer oeffnen
    Start-Process explorer.exe $target
})

$btnSync.Add_Click({
    $r = Get-SelectedRepo
    if (-not $r) { return }
    $name = $r.name
    $target = Join-Path $BASE $name
    if (-not (Test-Path (Join-Path $target ".git"))) {
        [System.Windows.Forms.MessageBox]::Show("$target ist kein Git-Repo. Erst 'Clone' verwenden.","GitHub Repo Picker",'OK','Warning') | Out-Null
        return
    }
    $lblStatus.Text = "sync $name ..."
    $form.Refresh()
    $owner   = $r.owner.login
    $urlAuth = "https://$USER`:$TOKEN@github.com/$owner/$name.git"
    $urlPub  = "https://github.com/$owner/$name.git"
    Push-Location $target
    & git remote set-url origin $urlAuth 2>&1 | Out-Null
    $branch = (& git rev-parse --abbrev-ref HEAD 2>$null)
    if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq "HEAD") { $branch = "main" }
    & git add -A 2>&1 | Out-Null
    $dirty = & git status --porcelain
    if ($dirty) { & git commit -m ("Auto commit " + (Get-Date -Format "yyyy-MM-dd HH:mm")) 2>&1 | Out-Null }
    & git pull --rebase origin $branch 2>&1 | Out-Null
    $pullCode = $LASTEXITCODE
    if ($pullCode -eq 0) { & git push origin $branch 2>&1 | Out-Null }
    & git remote set-url origin $urlPub 2>&1 | Out-Null
    Pop-Location
    if ($pullCode -eq 0 -and $LASTEXITCODE -eq 0) {
        $lblStatus.Text = "sync OK -> $target"
    } else {
        $lblStatus.Text = "sync-Konflikt / Fehler"
        [System.Windows.Forms.MessageBox]::Show("Sync fehlgeschlagen (Konflikt?). Bitte manuell pruefen.","GitHub Repo Picker",'OK','Warning') | Out-Null
    }
})

# Doppelklick = Clone
$lv.Add_DoubleClick({ $btnClone.PerformClick() })

# Enter im Filter fokussiert Liste
$txtFilter.Add_KeyDown({
    if ($_.KeyCode -eq 'Enter' -and $lv.Items.Count -gt 0) {
        $lv.Focus() | Out-Null
        $_.SuppressKeyPress = $true
    }
})

$form.Add_Shown({ Load-Repos })
[void]$form.ShowDialog()
