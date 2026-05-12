# --- Automatic Admin Restart (Self-Elevation) ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Styling & Colors ---
$color_bg      = [System.Drawing.Color]::FromArgb(45, 52, 71)
$color_sidebar = [System.Drawing.Color]::FromArgb(35, 40, 55)
$color_text    = [System.Drawing.Color]::White
$color_accent  = [System.Drawing.Color]::FromArgb(0, 120, 215)
$color_save    = [System.Drawing.Color]::FromArgb(40, 167, 69)
$color_delete  = [System.Drawing.Color]::FromArgb(220, 53, 69)
$font_main     = New-Object System.Drawing.Font("Segoe UI", 10)
$font_bold     = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# --- Files & Paths ---
$jobFile = "$PSScriptRoot\backup_jobs.json"
if (-not (Test-Path $jobFile)) { "{}" | Out-File $jobFile -Encoding utf8 }

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "proxmoxbackupclient_go-GUI"
$mainForm.Size = "950, 850"
$mainForm.StartPosition = "CenterScreen"
$mainForm.BackColor = $color_bg
$mainForm.ForeColor = $color_text

# --- Helper Functions ---
function Get-PhysicalDisks {
    return Get-CimInstance Win32_DiskDrive | ForEach-Object {
        $cleanId = $_.DeviceID -replace "PHYSICALDRIVE", "PhysicalDrive"
        @{ ID = $cleanId; Name = "Disk $($_.Index): $($_.Model) ($cleanId)" }
    }
}

function Update-List {
    $listBox.Items.Clear()
    if (Test-Path $jobFile) {
        $content = Get-Content $jobFile -Raw
        if ($content) {
            $jobs = $content | ConvertFrom-Json
            if ($jobs) {
                foreach ($n in $jobs.psobject.properties.name) { [void]$listBox.Items.Add($n) }
            }
        }
    }
}

# --- UI Components ---
$labelJob = New-Object System.Windows.Forms.Label
$labelJob.Text = "Backup Job Name"; $labelJob.Location = "30, 25"; $labelJob.AutoSize = $true; $labelJob.Font = $font_bold
$txtJobName = New-Object System.Windows.Forms.TextBox
$txtJobName.Location = "30, 50"; $txtJobName.Width = 350

$groupMode = New-Object System.Windows.Forms.GroupBox
$groupMode.Text = "Backup Mode"; $groupMode.Location = "30, 100"; $groupMode.Size = "450,90"; $groupMode.ForeColor = "White"
$radioDir = New-Object System.Windows.Forms.RadioButton
$radioDir.Text = "Directory (pbsdirectorybackup.exe)"; $radioDir.Checked = $true; $radioDir.Location = "20,30"; $radioDir.AutoSize = $true
$radioMachine = New-Object System.Windows.Forms.RadioButton
$radioMachine.Text = "Machine (pbsmachinebackup.exe)"; $radioMachine.Location = "20,55"; $radioMachine.AutoSize = $true
$groupMode.Controls.AddRange(@($radioDir, $radioMachine))

$panelSource = New-Object System.Windows.Forms.Panel
$panelSource.Location = "30, 210"; $panelSource.Size = "530, 180"
$lblSrc = New-Object System.Windows.Forms.Label
$lblSrc.Text = "Source Path:"; $lblSrc.Location = "0, 0"; $lblSrc.AutoSize = $true; $lblSrc.Font = $font_bold
$txtDirSource = New-Object System.Windows.Forms.TextBox
$txtDirSource.Location = "0, 25"; $txtDirSource.Width = 400

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."; $btnBrowse.Location = "410, 24"; $btnBrowse.Size = "90, 28"; $btnBrowse.FlatStyle = "Flat"; $btnBrowse.BackColor = [System.Drawing.Color]::Gray
$btnBrowse.Add_Click({
    $f = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($f.ShowDialog() -eq "OK") { $txtDirSource.Text = $f.SelectedPath }
})

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Location = "0, 25"; $checkedListBox.Size = "500, 140"; $checkedListBox.Visible = $false; $checkedListBox.BackColor = $color_sidebar; $checkedListBox.ForeColor = "White"

$radioDir.Add_CheckedChanged({ $txtDirSource.Visible = $true; $btnBrowse.Visible = $true; $lblSrc.Text = "Source Path:"; $checkedListBox.Visible = $false })
$radioMachine.Add_CheckedChanged({ 
    $txtDirSource.Visible = $false; $btnBrowse.Visible = $false; $lblSrc.Text = "Select Physical Drives:"; $checkedListBox.Visible = $true
    $checkedListBox.Items.Clear()
    (Get-PhysicalDisks) | ForEach-Object { [void]$checkedListBox.Items.Add($_.Name) }
})
$panelSource.Controls.AddRange(@($lblSrc, $txtDirSource, $btnBrowse, $checkedListBox))

$y = 410
$fields = @("PBS URL", "Fingerprint", "Token ID", "Secret", "Datastore", "Start Time (HH:mm)")
$inputs = @{}
foreach ($f in $fields) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = "${f}:"; $l.Location = "30, $y"; $l.AutoSize = $true
    $t = New-Object System.Windows.Forms.TextBox; $t.Location = "180, $y"; $t.Width = 350
    if ($f -eq "Secret") { $t.PasswordChar = "*" }
    if ($f -eq "Start Time (HH:mm)") { $t.Text = "02:00"; $t.Width = 80 }
    $mainForm.Controls.AddRange(@($l, $t)); $inputs[$f] = $t; $y += 35
}

$lblInterval = New-Object System.Windows.Forms.Label; $lblInterval.Text = "Interval:"; $lblInterval.Location = "30, $y"; $lblInterval.AutoSize = $true
$comboInterval = New-Object System.Windows.Forms.ComboBox; $comboInterval.Location = "180, $y"; $comboInterval.Width = 150; $comboInterval.DropDownStyle = "DropDownList"
$comboInterval.Items.AddRange(@("Daily", "Weekly (Mon)", "Hourly"))
$comboInterval.SelectedIndex = 0
$mainForm.Controls.AddRange(@($lblInterval, $comboInterval))

# --- Sidebar (Jobs) ---
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = "600, 50"; $listBox.Size = "300, 530"; $listBox.BackColor = $color_sidebar; $listBox.ForeColor = "White"
$listBox.Add_SelectedIndexChanged({
    $jobName = $listBox.SelectedItem; if (-not $jobName) { return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json
    $job = $jobs.$jobName
    $txtJobName.Text = $jobName
    $inputs["PBS URL"].Text = $job.url; $inputs["Fingerprint"].Text = $job.fp
    $inputs["Token ID"].Text = $job.token; $inputs["Secret"].Text = $job.secret
    $inputs["Datastore"].Text = $job.store
    $inputs["Start Time (HH:mm)"].Text = $job.time
    $comboInterval.SelectedItem = $job.interval
    if ($job.mode -eq "machine") {
        $radioMachine.Checked = $true
        for($i=0; $i -lt $checkedListBox.Items.Count; $i++) {
            $itemText = $checkedListBox.Items[$i]
            $driveIdInList = ($itemText -split '\(')[-1].Replace(')','')
            $checkedListBox.SetItemChecked($i, $job.source.Contains($driveIdInList))
        }
    } else { $radioDir.Checked = $true; $txtDirSource.Text = $job.source }
})

# --- Actions ---

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Job"; $btnSave.Location = "30, 680"; $btnSave.Size = "150, 45"; $btnSave.FlatStyle = "Flat"; $btnSave.BackColor = $color_save
$btnSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtJobName.Text)) { return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json
    if (-not $jobs) { $jobs = New-Object PSObject }

    $src = ""
    if($radioDir.Checked) { $src = $txtDirSource.Text } 
    else { 
        $selected = @()
        foreach ($item in $checkedListBox.CheckedItems) {
            $path = ($item -split '\(')[-1].Replace(')','')
            $selected += $path -replace "PHYSICALDRIVE", "PhysicalDrive"
        }
        $src = $selected -join ","
    }
    
    $jobData = [PSCustomObject]@{
        mode     = if($radioDir.Checked){"directory"}else{"machine"}
        source   = $src
        url      = $inputs["PBS URL"].Text
        fp       = $inputs["Fingerprint"].Text
        token    = $inputs["Token ID"].Text
        secret   = $inputs["Secret"].Text
        store    = $inputs["Datastore"].Text
        time     = $inputs["Start Time (HH:mm)"].Text
        interval = $comboInterval.SelectedItem
    }
    
    if ($jobs.PSObject.Properties[$txtJobName.Text]) { $jobs.PSObject.Properties.Remove($txtJobName.Text) }
    $jobs.PSObject.Properties.Add((New-Object System.Management.Automation.PSNoteProperty($txtJobName.Text, $jobData)))
    $jobs | ConvertTo-Json -Depth 10 | Out-File $jobFile -Encoding utf8
    Update-List
    [System.Windows.Forms.MessageBox]::Show("Job saved successfully.")
})

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Run Backup Now"; $btnRun.Location = "310, 680"; $btnRun.Size = "220, 45"; $btnRun.FlatStyle = "Flat"; $btnRun.BackColor = $color_accent
$btnRun.Add_Click({
    $jobName = $listBox.SelectedItem; if (-not $jobName) { return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json; $job = $jobs.$jobName
    
    if ($job.mode -eq "machine") { 
        $exe = "$PSScriptRoot\pbsmachinebackup.exe"
        $argString = "-baseurl `"$($job.url)`" -certfingerprint `"$($job.fp)`" -authid `"$($job.token)`" -secret `"$($job.secret)`" -datastore `"$($job.store)`""
        foreach ($d in $job.source.Split(",")) {
            $argString += " -backupdev $($d.Trim())"
        }
        Start-Process $exe -ArgumentList $argString -Wait
    } else { 
        $exe = "$PSScriptRoot\pbsdirectorybackup.exe"
        $args = @("-baseurl", $job.url, "-certfingerprint", $job.fp, "-authid", $job.token, "-secret", $job.secret, "-datastore", $job.store, "-backupdir", $job.source)
        Start-Process $exe -ArgumentList $args -Wait
    }
})

$btnSchedule = New-Object System.Windows.Forms.Button
$btnSchedule.Text = "Automate in Task Scheduler"; $btnSchedule.Location = "30, 740"; $btnSchedule.Size = "500, 45"; $btnSchedule.FlatStyle = "Flat"; $btnSchedule.BackColor = [System.Drawing.Color]::DimGray
$btnSchedule.Add_Click({
    $jobName = $listBox.SelectedItem; if (-not $jobName) { return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json; $job = $jobs.$jobName
    
    $exe = if($job.mode -eq "machine") { "$PSScriptRoot\pbsmachinebackup.exe" } else { "$PSScriptRoot\pbsdirectorybackup.exe" }
    $args = "-baseurl `"$($job.url)`" -certfingerprint `"$($job.fp)`" -authid `"$($job.token)`" -secret `"$($job.secret)`" -datastore `"$($job.store)`""
    
    if ($job.mode -eq "machine") {
        foreach ($d in $job.source.Split(",")) { $args += " -backupdev $($d.Trim())" }
    } else {
        $args += " -backupdir `"$($job.source)`""
    }
    
    $action = New-ScheduledTaskAction -Execute $exe -Argument $args -WorkingDirectory $PSScriptRoot
    $startTime = Get-Date $job.time
    
    switch ($job.interval) {
        "Daily" { $trigger = New-ScheduledTaskTrigger -Daily -At $startTime }
        "Weekly (Mon)" { $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At $startTime }
        "Hourly" { 
            $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
            $trigger.Repetition = (New-ScheduledTaskSettingsSet -RepeatInterval (New-TimeSpan -Hours 1)).Repetition 
        }
    }
    
    Register-ScheduledTask -TaskName "PBS_Backup_$jobName" -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest) -Force
    [System.Windows.Forms.MessageBox]::Show("Job successfully added to Task Scheduler.")
})

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete"; $btnDelete.Location = "190, 680"; $btnDelete.Size = "100, 45"; $btnDelete.FlatStyle = "Flat"; $btnDelete.BackColor = $color_delete
$btnDelete.Add_Click({
    $jobName = $listBox.SelectedItem; if (-not $jobName) { return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json
    if ([System.Windows.Forms.MessageBox]::Show("Are you sure you want to delete job '$jobName'?", "Confirm", "YesNo") -eq "Yes") {
        $jobs.PSObject.Properties.Remove($jobName)
        $jobs | ConvertTo-Json | Out-File $jobFile -Encoding utf8
        if (Get-ScheduledTask -TaskName "PBS_Backup_$jobName" -ErrorAction SilentlyContinue) { 
            Unregister-ScheduledTask -TaskName "PBS_Backup_$jobName" -Confirm:$false 
        }
        Update-List
    }
})

$mainForm.Controls.AddRange(@($labelJob, $txtJobName, $groupMode, $panelSource, $btnSave, $btnDelete, $btnRun, $btnSchedule, $listBox))
Update-List
$mainForm.ShowDialog()
