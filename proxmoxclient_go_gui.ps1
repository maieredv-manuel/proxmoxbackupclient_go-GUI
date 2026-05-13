Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Auto-Admin Elevation ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process "powershell.exe" -ArgumentList $argList -Verb "RunAs"
    exit
}

# Configuration Paths
$jobFile = "$PSScriptRoot\backup_jobs.json"
$mailFile = "$PSScriptRoot\email_settings.json"
if (-not (Test-Path $jobFile)) { "{}" | Out-File $jobFile -Encoding utf8 }
if (-not (Test-Path $mailFile)) { "{}" | Out-File $mailFile -Encoding utf8 }

$mainForm = New-Object System.Windows.Forms.Form
$mainForm.Text = "Proxmox Backup Ultimate Manager"
$mainForm.Size = "950, 950"
$mainForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$mainForm.ForeColor = "White"

# --- Helper Functions ---
function Get-PhysicalDisks {
    return Get-CimInstance Win32_DiskDrive | ForEach-Object { @{ ID = $_.DeviceID; Name = "Disk $($_.Index): $($_.Model) ($($_.DeviceID))" } }
}

function Update-List {
    $listBox.Items.Clear()
    $jobs = Get-Content $jobFile | ConvertFrom-Json
    if ($null -ne $jobs) {
        foreach ($n in $jobs.psobject.properties.name) { [void]$listBox.Items.Add($n) }
    }
}

function Get-MailArgs {
    if (-not (Test-Path $mailFile)) { return @() }
    $m = Get-Content $mailFile | ConvertFrom-Json
    if (-not $m.host) { return @() }
    $args = @("-mail-host", $m.host, "-mail-port", $m.port, "-mail-username", $m.user, "-mail-password", $m.pass, "-mail-from", $m.from, "-mail-to", $m.to)
    if ($m.insecure) { $args += "-mail-insecure" }
    if ($m.subject) { $args += @("-mail-subject-template", $m.subject) }
    if ($m.body) { $args += @("-mail-body-template", $m.body) }
    return $args
}

# --- UI: Job Name & Type ---
$labelJob = New-Object System.Windows.Forms.Label; $labelJob.Text = "Job Name:"; $labelJob.Location = "20, 20"; $labelJob.AutoSize = $true
$txtJobName = New-Object System.Windows.Forms.TextBox; $txtJobName.Location = "150, 20"; $txtJobName.Width = 250

$groupMode = New-Object System.Windows.Forms.GroupBox; $groupMode.Text = "Backup Type"; $groupMode.Location = "20, 60"; $groupMode.Size = "400,80"; $groupMode.ForeColor = "White"
$radioDir = New-Object System.Windows.Forms.RadioButton; $radioDir.Text = "Directory"; $radioDir.Checked = $true; $radioDir.Location = "10,25"
$radioMachine = New-Object System.Windows.Forms.RadioButton; $radioMachine.Text = "Machine (Disk)"; $radioMachine.Location = "10,50"
$groupMode.Controls.AddRange(@($radioDir, $radioMachine))

# Source Selection
$lblSrc = New-Object System.Windows.Forms.Label; $lblSrc.Text = "Source:"; $lblSrc.Location = "20, 160"; $lblSrc.AutoSize = $true
$txtDirSource = New-Object System.Windows.Forms.TextBox; $txtDirSource.Location = "150, 160"; $txtDirSource.Width = 350
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text = "..."; $btnBrowse.Location = "510, 158"; $btnBrowse.Width = 40; $btnBrowse.BackColor = "DimGray"
$btnBrowse.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtDirSource.Text = $folderBrowser.SelectedPath }
})

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox; $checkedListBox.Location = "150, 160"; $checkedListBox.Size = "400, 100"; $checkedListBox.Visible = $false; $checkedListBox.BackColor = "DimGray"; $checkedListBox.ForeColor = "White"

$radioDir.Add_CheckedChanged({ $txtDirSource.Visible = $btnBrowse.Visible = $true; $checkedListBox.Visible = $false; $lblSrc.Text = "Folder Path:" })
$radioMachine.Add_CheckedChanged({ 
    $txtDirSource.Visible = $btnBrowse.Visible = $false; $checkedListBox.Visible = $true; $lblSrc.Text = "Select Disks:"
    $checkedListBox.Items.Clear(); (Get-PhysicalDisks) | ForEach-Object { [void]$checkedListBox.Items.Add($_.Name) }
})

# PBS Settings
$y = 280
$fields = @("PBS URL", "Fingerprint", "Token ID", "Secret", "Datastore")
$inputs = @{}
foreach ($f in $fields) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = "$($f):"; $l.Location = "20, $y"; $l.AutoSize = $true
    $t = New-Object System.Windows.Forms.TextBox; $t.Location = "150, $y"; $t.Width = 400
    if ($f -eq "Secret") { $t.PasswordChar = "*" }
    $mainForm.Controls.Add($l); $mainForm.Controls.Add($t); $inputs[$f] = $t; $y += 35
}

# --- Planning Section ---
$groupSched = New-Object System.Windows.Forms.GroupBox; $groupSched.Text = "Scheduling"; $groupSched.Location = "20, $y"; $groupSched.Size = "550,160"; $groupSched.ForeColor = "White"
$chkEnableSched = New-Object System.Windows.Forms.CheckBox; $chkEnableSched.Text = "Enable scheduled backup"; $chkEnableSched.Location = "15,25"; $chkEnableSched.AutoSize = $true

$lblTime = New-Object System.Windows.Forms.Label; $lblTime.Text = "Time (HH:mm):"; $lblTime.Location = "15,65"; $lblTime.AutoSize = $true
$txtTime = New-Object System.Windows.Forms.TextBox; $txtTime.Text = "02:00"; $txtTime.Location = "120,62"; $txtTime.Width = 60

$lblInt = New-Object System.Windows.Forms.Label; $lblInt.Text = "Interval:"; $lblInt.Location = "15,105"; $lblInt.AutoSize = $true
$cmbInt = New-Object System.Windows.Forms.ComboBox; $cmbInt.Location = "120,102"; $cmbInt.Width = 120; $cmbInt.DropDownStyle = "DropDownList"
$cmbInt.Items.AddRange(@("Daily", "Weekly", "Hourly"))
$cmbInt.SelectedIndex = 0

$lblDay = New-Object System.Windows.Forms.Label; $lblDay.Text = "Day:"; $lblDay.Location = "260,105"; $lblDay.Visible = $false; $lblDay.AutoSize = $true
$cmbDay = New-Object System.Windows.Forms.ComboBox; $cmbDay.Location = "310,102"; $cmbDay.Width = 120; $cmbDay.Visible = $false; $cmbDay.DropDownStyle = "DropDownList"
$cmbDay.Items.AddRange(@("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))
$cmbDay.SelectedIndex = 0

$cmbInt.Add_SelectedIndexChanged({ $cmbDay.Visible = $lblDay.Visible = ($cmbInt.SelectedItem -eq "Weekly") })
$groupSched.Controls.AddRange(@($chkEnableSched, $lblTime, $txtTime, $lblInt, $cmbInt, $lblDay, $cmbDay))
$y += 180

# --- Email Settings ---
$btnEmailSettings = New-Object System.Windows.Forms.Button; $btnEmailSettings.Text = "Global Email Configuration"; $btnEmailSettings.Location = "20, $y"; $btnEmailSettings.Size = "250, 40"; $btnEmailSettings.BackColor = "DimGray"
$btnEmailSettings.Add_Click({
    $eForm = New-Object System.Windows.Forms.Form; $eForm.Text = "Global Email Settings"; $eForm.Size = "500,620"; $eForm.BackColor = "DimGray"; $eForm.ForeColor = "White"; $eForm.StartPosition = "CenterParent"
    $m = if (Test-Path $mailFile) { Get-Content $mailFile | ConvertFrom-Json } else { @{} }
    $ey = 20; $mFields = @("Host", "Port", "User", "Pass", "From", "To", "Subject", "Body")
    $mIns = @{}
    foreach($f in $mFields){
        $l = New-Object System.Windows.Forms.Label; $l.Text = "$($f):"; $l.Location = "20, $ey"; $ey+=25
        $t = New-Object System.Windows.Forms.TextBox; $t.Location = "20, $ey"; $t.Width = 440; $t.Text = $m.$f; $ey+=35
        $eForm.Controls.AddRange(@($l, $t)); $mIns[$f] = $t
    }
    $cInsecure = New-Object System.Windows.Forms.CheckBox; $cInsecure.Text = "Allow Insecure TLS"; $cInsecure.Location = "20, $ey"; $cInsecure.Checked = $m.insecure; $ey+=40
    $bSaveM = New-Object System.Windows.Forms.Button; $bSaveM.Text = "Save Email Settings"; $bSaveM.Location = "20, $ey"; $bSaveM.Width = 150; $bSaveM.Add_Click({
        @{host=$mIns["Host"].Text; port=$mIns["Port"].Text; user=$mIns["User"].Text; pass=$mIns["Pass"].Text; from=$mIns["From"].Text; to=$mIns["To"].Text; insecure=$cInsecure.Checked; subject=$mIns["Subject"].Text; body=$mIns["Body"].Text} | ConvertTo-Json | Out-File $mailFile
        $eForm.Close()
    })
    $eForm.Controls.AddRange(@($cInsecure, $bSaveM)); $eForm.ShowDialog()
})

$listBox = New-Object System.Windows.Forms.ListBox; $listBox.Location = "600, 20"; $listBox.Size = "300, 600"; $listBox.BackColor = "Black"; $listBox.ForeColor = "White"

# --- ACTION Logic: Run Job Now ---
$btnRun = New-Object System.Windows.Forms.Button; $btnRun.Text = "RUN JOB NOW"; $btnRun.Location = "20, 800"; $btnRun.Size = "180, 50"; $btnRun.BackColor = "SteelBlue"; $btnRun.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnRun.Add_Click({
    $jName = $listBox.SelectedItem; if(-not $jName){ [System.Windows.Forms.MessageBox]::Show("Please select a job from the list first."); return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json; $job = $jobs.$jName
    
    $exe = if($job.mode -eq "machine"){"machinebackup.exe"}else{"proxmoxbackupgo.exe"}
    $args = "-baseurl `"$($job.url)`" -certfingerprint `"$($job.fp)`" -authid `"$($job.token)`" -secret `"$($job.secret)`" -datastore `"$($job.store)`""
    if($job.mode -eq "machine"){ foreach($d in $job.source.Split(",")){ if($d.Trim()){ $args += " -drive `"$($d.Trim())`"" } } }
    else { $args += " -backupdir `"$($job.source)`"" }
    
    $mArgs = Get-MailArgs
    if ($mArgs) { $args += " " + ($mArgs -join " ") }
    
    Start-Process "$PSScriptRoot\$exe" -ArgumentList $args -Wait
})

# --- SAVE JOB Logic ---
$btnSave = New-Object System.Windows.Forms.Button; $btnSave.Text = "SAVE JOB"; $btnSave.Location = "210, 800"; $btnSave.Size = "180, 50"; $btnSave.BackColor = "DarkGreen"
$btnSave.Add_Click({
    if (-not $txtJobName.Text) { [System.Windows.Forms.MessageBox]::Show("Please enter a job name."); return }
    $jobs = Get-Content $jobFile | ConvertFrom-Json
    if ($null -eq $jobs) { $jobs = New-Object PSObject }

    $modeVal = if($radioDir.Checked){"dir"}else{"machine"}
    $src = ""
    if($radioDir.Checked){
        $src = $txtDirSource.Text
    } else {
        $selected = @()
        foreach ($item in $checkedListBox.CheckedItems) {
            if ($item -like "*\\.\PhysicalDrive*") {
                $parts = $item.Split("()")
                foreach($p in $parts) { if($p -like "\\.\*") { $selected += $p.Trim() } }
            }
        }
        $src = $selected -join ","
    }
    
    $jobData = @{ 
        mode = $modeVal
        source = $src
        url = $inputs["PBS URL"].Text
        fp = $inputs["Fingerprint"].Text
        token = $inputs["Token ID"].Text
        secret = $inputs["Secret"].Text
        store = $inputs["Datastore"].Text
        sched = $chkEnableSched.Checked
        time = $txtTime.Text
        interval = $cmbInt.Text
        day = $cmbDay.Text 
    }
    
    if ($jobs.PSObject.Properties[$txtJobName.Text]) { $jobs.PSObject.Properties.Remove($txtJobName.Text) }
    $jobs | Add-Member -MemberType NoteProperty -Name $txtJobName.Text -Value $jobData -Force
    $jobs | ConvertTo-Json | Out-File $jobFile -Encoding utf8
    
    $tName = "PBS_Backup_$($txtJobName.Text)"
    if ($chkEnableSched.Checked) {
        $exe = if($jobData.mode -eq "machine"){"machinebackup.exe"}else{"proxmoxbackupgo.exe"}
        $args = "-baseurl `"$($jobData.url)`" -certfingerprint `"$($jobData.fp)`" -authid `"$($jobData.token)`" -secret `"$($jobData.secret)`" -datastore `"$($jobData.store)`""
        if($jobData.mode -eq "machine"){ foreach($d in $jobData.source.Split(",")){ if($d.Trim()){ $args += " -drive `"$($d.Trim())`"" } } }
        else { $args += " -backupdir `"$($jobData.source)`"" }
        $mArgs = Get-MailArgs
        if ($mArgs) { $args += " " + ($mArgs -join " ") }
        
        $action = New-ScheduledTaskAction -Execute "$PSScriptRoot\$exe" -Argument $args -WorkingDirectory $PSScriptRoot
        $startTime = Get-Date $jobData.time
        switch ($jobData.interval) {
            "Daily" { $trigger = New-ScheduledTaskTrigger -Daily -At $startTime }
            "Weekly" { $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $jobData.day -At $startTime }
            "Hourly" { $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date); $trigger.Repetition = (New-ScheduledTaskSettingsSet -RepeatInterval (New-TimeSpan -Hours 1)).Repetition }
        }
        Register-ScheduledTask -TaskName $tName -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest) -Force
    } else { Unregister-ScheduledTask -TaskName $tName -Confirm:$false -ErrorAction SilentlyContinue }
    
    Update-List
    [System.Windows.Forms.MessageBox]::Show("Job saved and synchronized.")
})

$btnDelete = New-Object System.Windows.Forms.Button; $btnDelete.Text = "DELETE JOB"; $btnDelete.Location = "400, 800"; $btnDelete.Size = "150, 50"; $btnDelete.BackColor = "Firebrick"
$btnDelete.Add_Click({
    if($listBox.SelectedItem){ 
        if ([System.Windows.Forms.MessageBox]::Show("Delete '$($listBox.SelectedItem)'?", "Confirm", "YesNo") -eq "Yes") {
            $jobs = Get-Content $jobFile | ConvertFrom-Json
            $jobs.PSObject.Properties.Remove($listBox.SelectedItem)
            $jobs | ConvertTo-Json | Out-File $jobFile
            Unregister-ScheduledTask -TaskName "PBS_Backup_$($listBox.SelectedItem)" -Confirm:$false -ErrorAction SilentlyContinue
            Update-List 
        }
    }
})

$listBox.Add_SelectedIndexChanged({
    $jName = $listBox.SelectedItem; if(-not $jName){return}
    $j = (Get-Content $jobFile | ConvertFrom-Json).$jName
    $txtJobName.Text = $jName; $inputs["PBS URL"].Text = $j.url; $inputs["Fingerprint"].Text = $j.fp; $inputs["Token ID"].Text = $j.token; $inputs["Secret"].Text = $j.secret; $inputs["Datastore"].Text = $j.store
    $chkEnableSched.Checked = $j.sched; $txtTime.Text = $j.time
    if($j.interval) { $cmbInt.SelectedIndex = $cmbInt.Items.IndexOf($j.interval) }
    if($j.day) { $cmbDay.SelectedIndex = $cmbDay.Items.IndexOf($j.day) }
    if($j.mode -eq "machine"){$radioMachine.Checked = $true}else{$radioDir.Checked = $true; $txtDirSource.Text = $j.source}
})

$mainForm.Controls.AddRange(@($labelJob, $txtJobName, $groupMode, $lblSrc, $txtDirSource, $btnBrowse, $checkedListBox, $groupSched, $btnEmailSettings, $btnRun, $btnSave, $btnDelete, $listBox))
Update-List
$mainForm.ShowDialog()
