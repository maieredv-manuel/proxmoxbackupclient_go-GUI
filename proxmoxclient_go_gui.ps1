# --- 1. Thread & Admin Check (WPF REQUIRES STA-Mode!) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isSTA = ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA')

if (-not $isAdmin -or -not $isSTA) {
    $argList = "-STA -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if (-not $isAdmin) {
        Start-Process "powershell.exe" -ArgumentList $argList -Verb "RunAs"
    } else {
        Start-Process "powershell.exe" -ArgumentList $argList
    }
    exit
}

# --- 2. Load WPF Assemblies & Setup UTF8 without BOM ---
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase


$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# --- 3. Configuration Paths ---
$jobFile = "$PSScriptRoot\backup_jobs.json"
$mailFile = "$PSScriptRoot\email_settings.json"
if (-not (Test-Path $jobFile)) { [System.IO.File]::WriteAllText($jobFile, "{}", $utf8NoBom) }
if (-not (Test-Path $mailFile)) { [System.IO.File]::WriteAllText($mailFile, "{}", $utf8NoBom) }

# --- 4. XAML UI Definition ---
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Proxmox Backup Client GUI" Height="850" Width="1000" 
        Background="#1E1E1E" Foreground="White" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#CCCCCC"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Margin" Value="0,5,0,0"/>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#2D2D2D"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderBrush" Value="#3F3F46"/>
            <Setter Property="Padding" Value="5"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
        </Style>
        <Style x:Key="ModernBtn" TargetType="Button">
            <Setter Property="Padding" Value="10"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
    </Window.Resources>
    
    <Grid Margin="20">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*"/>
            <ColumnDefinition Width="300"/>
        </Grid.ColumnDefinitions>
        
        <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="0,0,20,0">
                <TextBlock Text="Backup Job Configuration" FontSize="20" FontWeight="Bold" Margin="0,0,0,20"/>
                
                <Label Content="Job Name:"/>
                <TextBox x:Name="txtJobName" />

                <GroupBox Header="Backup Type" Foreground="White" Margin="0,15,0,10" Padding="10">
                    <StackPanel Orientation="Horizontal">
                        <RadioButton x:Name="radioDir" Content="Directory" Foreground="White" Margin="0,0,20,0"/>
                        <RadioButton x:Name="radioMachine" Content="Machine (Disk)" Foreground="White" />
                    </StackPanel>
                </GroupBox>

                <Label x:Name="lblSrc" Content="Source Folder:"/>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="txtDirSource" Grid.Column="0"/>
                    <Button x:Name="btnBrowse" Content="..." Grid.Column="1" Width="40" Margin="5,0,0,0" Background="#3F3F46" Foreground="White"/>
                </Grid>
                
                <ListBox x:Name="listDisks" Height="180" Background="#2D2D2D" Foreground="White" BorderBrush="#3F3F46" Padding="5" Visibility="Collapsed" SelectionMode="Multiple"/>

                <Label Content="PBS URL:"/>
                <TextBox x:Name="txtUrl" />
                
                <Label Content="Fingerprint:"/>
                <TextBox x:Name="txtFp" />
                
                <Label Content="Token ID:"/>
                <TextBox x:Name="txtToken" />
                
                <Label Content="Secret:"/>
                <PasswordBox x:Name="txtSecret" Background="#2D2D2D" Foreground="White" BorderBrush="#3F3F46" Padding="5"/>
                
                <Label Content="Datastore:"/>
                <TextBox x:Name="txtStore" />

                <GroupBox Header="Scheduling" Foreground="White" Margin="0,20,0,10" Padding="10">
                    <StackPanel>
                        <CheckBox x:Name="chkEnableSched" Content="Enable scheduled backup" Foreground="White" Margin="0,0,0,10"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="100"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Label Content="Time:" Grid.Column="0" Margin="0,0,10,0"/>
                            <TextBox x:Name="txtTime" Text="02:00" Grid.Column="1"/>
                            
                            <Label Content="Interval:" Grid.Column="2" Margin="15,0,10,0"/>
                            <ComboBox x:Name="cmbInt" Grid.Column="3" Background="#2D2D2D">
                                <ComboBoxItem Content="Daily" IsSelected="True"/>
                                <ComboBoxItem Content="Weekly"/>
                                <ComboBoxItem Content="Hourly"/>
                            </ComboBox>
                        </Grid>
                        <StackPanel x:Name="panelWeekly" Visibility="Collapsed" Margin="0,10,0,0">
                             <Label Content="Day:"/>
                             <ComboBox x:Name="cmbDay">
                                <ComboBoxItem Content="Monday" IsSelected="True"/><ComboBoxItem Content="Tuesday"/><ComboBoxItem Content="Wednesday"/>
                                <ComboBoxItem Content="Thursday"/><ComboBoxItem Content="Friday"/><ComboBoxItem Content="Saturday"/><ComboBoxItem Content="Sunday"/>
                             </ComboBox>
                        </StackPanel>
                    </StackPanel>
                </GroupBox>

                <Button x:Name="btnMail" Content="Global Email Configuration" Style="{StaticResource ModernBtn}" Background="#3F3F46" Margin="0,10,0,20"/>
            </StackPanel>
        </ScrollViewer>

        <Grid Grid.Column="1">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/> 
                <RowDefinition Height="*"/> 
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <TextBlock Text="Saved Jobs" FontSize="16" Margin="0,0,0,10" Grid.Row="0"/>
            
            <ListBox x:Name="listBoxJobs" Background="#2D2D2D" Foreground="White" BorderBrush="#3F3F46" Padding="5" Grid.Row="1"/>
            
            <StackPanel Grid.Row="2" Margin="0,20,0,0">
                <Button x:Name="btnNew" Content="NEW JOB (CLEAR)" Style="{StaticResource ModernBtn}" Background="#6C757D" FontWeight="Bold" Margin="0,5"/>
                <Button x:Name="btnRun" Content="RUN JOB NOW" Style="{StaticResource ModernBtn}" Background="#007ACC" FontWeight="Bold" Margin="0,5"/>
                <Button x:Name="btnSave" Content="SAVE JOB" Style="{StaticResource ModernBtn}" Background="#28A745" FontWeight="Bold" Margin="0,5"/>
                <Button x:Name="btnDelete" Content="DELETE JOB" Style="{StaticResource ModernBtn}" Background="#DC3545" Margin="0,5"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
'@

$Window = [System.Windows.Markup.XamlReader]::Parse($xaml)

# --- 5. Mapping UI Elements ---
$txtJobName = $Window.FindName("txtJobName")
$radioDir = $Window.FindName("radioDir")
$radioMachine = $Window.FindName("radioMachine")
$txtDirSource = $Window.FindName("txtDirSource")
$lblSrc = $Window.FindName("lblSrc")
$listDisks = $Window.FindName("listDisks")
$btnBrowse = $Window.FindName("btnBrowse")
$txtUrl = $Window.FindName("txtUrl")
$txtFp = $Window.FindName("txtFp")
$txtToken = $Window.FindName("txtToken")
$txtSecret = $Window.FindName("txtSecret")
$txtStore = $Window.FindName("txtStore")
$chkEnableSched = $Window.FindName("chkEnableSched")
$txtTime = $Window.FindName("txtTime")
$cmbInt = $Window.FindName("cmbInt")
$panelWeekly = $Window.FindName("panelWeekly")
$cmbDay = $Window.FindName("cmbDay")
$btnMail = $Window.FindName("btnMail")
$listBoxJobs = $Window.FindName("listBoxJobs")
$btnNew = $Window.FindName("btnNew")
$btnRun = $Window.FindName("btnRun")
$btnSave = $Window.FindName("btnSave")
$btnDelete = $Window.FindName("btnDelete")

# --- 6. Helper Functions ---
function Get-PhysicalDisks {
    return Get-CimInstance Win32_DiskDrive | ForEach-Object { 
        $rawId = $_.DeviceID
        $fixedId = $rawId.Replace("PHYSICALDRIVE", "PhysicalDrive").Replace("physicaldrive", "PhysicalDrive")
        [PSCustomObject]@{ ID = $fixedId; Name = "Disk $($_.Index): $($_.Model) ($($fixedId))" } 
    }
}

function Update-List {
    $listBoxJobs.Items.Clear()
    $jobsStr = [System.IO.File]::ReadAllText($jobFile)
    $jobs = $jobsStr | ConvertFrom-Json
    if ($null -ne $jobs) {
        foreach ($n in $jobs.psobject.properties.name) { [void]$listBoxJobs.Items.Add($n) }
    }
}

function Update-ConfigFile {
    param($jName, $jobData)
    
    $configData = [ordered]@{
        baseurl = $jobData.url
        certfingerprint = $jobData.fp
        authid = $jobData.token
        secret = $jobData.secret
        datastore = $jobData.store
    }

    if ($jobData.mode -eq "machine") {
        $disks = @($jobData.source.Split(",", [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object { $_.Trim() })
        if ($disks.Count -eq 1) { $configData.backupdev = $disks[0] } else { $configData.backupdev = $disks }
    } else {
        $configData.backupdir = $jobData.source
    }

    if (Test-Path $mailFile) {
        $mailStr = [System.IO.File]::ReadAllText($mailFile)
        $m = $mailStr | ConvertFrom-Json
        if ($null -ne $m -and -not [string]::IsNullOrWhiteSpace($m.host)) {
            
            $smtpObj = [ordered]@{
                host = $m.host
                port = $m.port
                username = $m.user
                password = $m.pass
                insecure = [bool]$m.insecure
                template = [ordered]@{
                    subject = $m.subject
                    body = $m.body
                }
                mails = @(
                    [ordered]@{
                        from = $m.from
                        to = $m.to
                    }
                )
            }
            
            $configData.smtp = $smtpObj
        }
    }
    
    $configPath = "$PSScriptRoot\config_$($jName).json"
    
    $jsonContent = $configData | ConvertTo-Json -Depth 10
    
    [System.IO.File]::WriteAllText($configPath, $jsonContent, $utf8NoBom)
    
    return $configPath
}

# --- 7. Event Handlers ---
$radioDir.Add_Checked({
    $txtDirSource.Visibility = "Visible"
    $btnBrowse.Visibility = "Visible"
    $listDisks.Visibility = "Collapsed"
    $lblSrc.Content = "Source Folder:"
    $Window.Height = 850
})

$radioMachine.Add_Checked({
    $txtDirSource.Visibility = "Collapsed"
    $btnBrowse.Visibility = "Collapsed"
    $listDisks.Visibility = "Visible"
    $lblSrc.Content = "Select Disks:"
    
    $listDisks.Items.Clear()
    (Get-PhysicalDisks) | ForEach-Object { [void]$listDisks.Items.Add($_.Name) }
    $Window.Height = 1000
})

$radioDir.IsChecked = $true

$cmbInt.Add_SelectionChanged({
    if ($cmbInt.SelectedItem.Content -eq "Weekly") { $panelWeekly.Visibility = "Visible" } else { $panelWeekly.Visibility = "Collapsed" }
})

$btnBrowse.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtDirSource.Text = $folderBrowser.SelectedPath }
})

$btnNew.Add_Click({
    $listBoxJobs.SelectedItem = $null
    $txtJobName.Text = ""
    $radioDir.IsChecked = $true
    $txtDirSource.Text = ""
    $listDisks.UnselectAll()
    $txtUrl.Text = ""
    $txtFp.Text = ""
    $txtToken.Text = ""
    $txtSecret.Password = ""
    $txtStore.Text = ""
    $chkEnableSched.IsChecked = $false
    $txtTime.Text = "02:00"
    $cmbInt.SelectedIndex = 0
    $cmbDay.SelectedIndex = 0
})

$btnSave.Add_Click({
    if (-not $txtJobName.Text) { [System.Windows.MessageBox]::Show("Job name required.") | Out-Null; return }
    
    $jobsStr = [System.IO.File]::ReadAllText($jobFile)
    $jobs = $jobsStr | ConvertFrom-Json
    if ($null -eq $jobs) { $jobs = New-Object PSObject }
    
    $modeVal = if($radioDir.IsChecked){"dir"}else{"machine"}
    $src = ""
    if($radioDir.IsChecked){ $src = $txtDirSource.Text } else {
        $selected = @()
        foreach ($item in $listDisks.SelectedItems) {
            if ($item -match '\(([^)]+)\)') { $selected += $matches[1].Replace("PHYSICALDRIVE", "PhysicalDrive") }
        }
        $src = $selected -join ","
    }

    $jobData = @{ 
        mode=$modeVal; source=$src; url=$txtUrl.Text; fp=$txtFp.Text; 
        token=$txtToken.Text; secret=$txtSecret.Password; store=$txtStore.Text; 
        sched=$chkEnableSched.IsChecked; time=$txtTime.Text; 
        interval=$cmbInt.Text; day=$cmbDay.Text 
    }

    if ($jobs.PSObject.Properties[$txtJobName.Text]) { $jobs.PSObject.Properties.Remove($txtJobName.Text) }
    $jobs | Add-Member -MemberType NoteProperty -Name $txtJobName.Text -Value $jobData -Force
    
    $jobsJson = $jobs | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($jobFile, $jobsJson, $utf8NoBom)
    
    $configPath = Update-ConfigFile -jName $txtJobName.Text -jobData $jobData
    
    $tName = "PBS_Backup_$($txtJobName.Text)"
    if ($chkEnableSched.IsChecked) {
        $exe = if($modeVal -eq "machine"){"pbsmachinebackup.exe"}else{"pbsdirectorybackup.exe"}
        $action = New-ScheduledTaskAction -Execute "$PSScriptRoot\$exe" -Argument "-config `"$configPath`"" -WorkingDirectory $PSScriptRoot
        $startTime = Get-Date $txtTime.Text
        switch ($cmbInt.Text) {
            "Daily" { $trigger = New-ScheduledTaskTrigger -Daily -At $startTime }
            "Weekly" { $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $cmbDay.Text -At $startTime }
            "Hourly" { $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date); $trigger.Repetition = (New-ScheduledTaskSettingsSet -RepeatInterval (New-TimeSpan -Hours 1)).Repetition }
        }
        Register-ScheduledTask -TaskName $tName -Action $action -Trigger $trigger -Principal (New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest) -Force
    } else {
        Unregister-ScheduledTask -TaskName $tName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Update-List
    [System.Windows.MessageBox]::Show("Job saved & Config JSON generated.") | Out-Null
})

$btnRun.Add_Click({
    $jName = $listBoxJobs.SelectedItem; if(-not $jName){ [System.Windows.MessageBox]::Show("Select job first.") | Out-Null; return }
    $jobsStr = [System.IO.File]::ReadAllText($jobFile)
    $jobs = $jobsStr | ConvertFrom-Json; $job = $jobs.$jName
    $exe = if($job.mode -eq "machine"){"pbsmachinebackup.exe"}else{"pbsdirectorybackup.exe"}
    
    $configPath = "$PSScriptRoot\config_$($jName).json"
    if (-not (Test-Path $configPath)) {
        [System.Windows.MessageBox]::Show("Config not found. Please click 'SAVE JOB' once to generate it.") | Out-Null
        return
    }
    
    Start-Process "powershell.exe" -ArgumentList "-NoExit -Command `"& '$PSScriptRoot\$exe' -config '$configPath'`""
})

$btnDelete.Add_Click({
    if($listBoxJobs.SelectedItem){ 
        if ([System.Windows.MessageBox]::Show("Delete '$($listBoxJobs.SelectedItem)'?", "Confirm", "YesNo") -eq "Yes") {
            $jobsStr = [System.IO.File]::ReadAllText($jobFile)
            $jobs = $jobsStr | ConvertFrom-Json
            $jobs.PSObject.Properties.Remove($listBoxJobs.SelectedItem)
            
            $jobsJson = $jobs | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($jobFile, $jobsJson, $utf8NoBom)
            
            Unregister-ScheduledTask -TaskName "PBS_Backup_$($listBoxJobs.SelectedItem)" -Confirm:$false -ErrorAction SilentlyContinue
            Update-List 
            
            $configPath = "$PSScriptRoot\config_$($listBoxJobs.SelectedItem).json"
            if (Test-Path $configPath) { Remove-Item $configPath -Force }
            
            $btnNew.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        }
    }
})

$listBoxJobs.Add_SelectionChanged({
    $jName = $listBoxJobs.SelectedItem; if(-not $jName){return}
    $jobsStr = [System.IO.File]::ReadAllText($jobFile)
    $j = ($jobsStr | ConvertFrom-Json).$jName
    $txtJobName.Text = $jName; $txtUrl.Text = $j.url; $txtFp.Text = $j.fp; $txtToken.Text = $j.token; $txtSecret.Password = $j.secret; $txtStore.Text = $j.store
    $chkEnableSched.IsChecked = $j.sched; $txtTime.Text = $j.time
    
    if ($j.interval) {
        foreach ($item in $cmbInt.Items) { if ($item.Content -eq $j.interval) { $cmbInt.SelectedItem = $item; break } }
    }
    if ($j.day) {
        foreach ($item in $cmbDay.Items) { if ($item.Content -eq $j.day) { $cmbDay.SelectedItem = $item; break } }
    }
    
    if($j.mode -eq "machine"){$radioMachine.IsChecked = $true}else{$radioDir.IsChecked = $true; $txtDirSource.Text = $j.source}
})

$btnMail.Add_Click({
    $mailXaml = @'
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Global Email Settings" Height="680" Width="450" 
            Background="#1E1E1E" Foreground="White" WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
        <Window.Resources>
            <Style TargetType="Label">
                <Setter Property="Foreground" Value="#CCCCCC"/>
                <Setter Property="FontSize" Value="12"/>
                <Setter Property="Margin" Value="0,5,0,0"/>
            </Style>
            <Style TargetType="TextBox">
                <Setter Property="Background" Value="#2D2D2D"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderBrush" Value="#3F3F46"/>
                <Setter Property="Padding" Value="5"/>
                <Setter Property="VerticalAlignment" Value="Center"/>
            </Style>
            <Style TargetType="PasswordBox">
                <Setter Property="Background" Value="#2D2D2D"/>
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="BorderBrush" Value="#3F3F46"/>
                <Setter Property="Padding" Value="5"/>
                <Setter Property="VerticalAlignment" Value="Center"/>
            </Style>
        </Window.Resources>
        
        <Grid Margin="20">
            <Grid.RowDefinitions>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            
            <StackPanel Grid.Row="0">
                <TextBlock Text="SMTP Configuration" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>
                
                <Label Content="Host (Server):"/>
                <TextBox x:Name="txtMHost" />
                
                <Label Content="Port:"/>
                <TextBox x:Name="txtMPort" />
                
                <Label Content="Username:"/>
                <TextBox x:Name="txtMUser" />
                
                <Label Content="Password:"/>
                <PasswordBox x:Name="txtMPass" />
                
                <Label Content="From Address:"/>
                <TextBox x:Name="txtMFrom" />
                
                <Label Content="To Address:"/>
                <TextBox x:Name="txtMTo" />
                
                <Label Content="Subject Template:"/>
                <TextBox x:Name="txtMSubject" />
                
                <Label Content="Body Template:"/>
                <TextBox x:Name="txtMBody" Height="60" TextWrapping="Wrap" AcceptsReturn="True" VerticalScrollBarVisibility="Auto"/>
                
                <CheckBox x:Name="chkMInsecure" Content="Allow Insecure TLS" Foreground="White" Margin="0,15,0,0"/>
            </StackPanel>
            
            <Button x:Name="btnSaveMail" Grid.Row="1" Content="SAVE EMAIL SETTINGS" Background="#28A745" Foreground="White" FontWeight="Bold" Padding="10" BorderThickness="0" Margin="0,15,0,0" Cursor="Hand"/>
        </Grid>
    </Window>
'@
    
    $MailWindow = [System.Windows.Markup.XamlReader]::Parse($mailXaml)
    
    $txtMHost = $MailWindow.FindName("txtMHost")
    $txtMPort = $MailWindow.FindName("txtMPort")
    $txtMUser = $MailWindow.FindName("txtMUser")
    $txtMPass = $MailWindow.FindName("txtMPass")
    $txtMFrom = $MailWindow.FindName("txtMFrom")
    $txtMTo = $MailWindow.FindName("txtMTo")
    $txtMSubject = $MailWindow.FindName("txtMSubject")
    $txtMBody = $MailWindow.FindName("txtMBody")
    $chkMInsecure = $MailWindow.FindName("chkMInsecure")
    $btnSaveMail = $MailWindow.FindName("btnSaveMail")
    
    if (Test-Path $mailFile) {
        $mailStr = [System.IO.File]::ReadAllText($mailFile)
        $m = $mailStr | ConvertFrom-Json
        if ($null -ne $m -and $null -ne $m.host) {
            $txtMHost.Text = $m.host
            $txtMPort.Text = $m.port
            $txtMUser.Text = $m.user
            $txtMPass.Password = $m.pass
            $txtMFrom.Text = $m.from
            $txtMTo.Text = $m.to
            $txtMSubject.Text = $m.subject
            $txtMBody.Text = $m.body
            if ($m.insecure) { $chkMInsecure.IsChecked = $true }
        }
    }
    
    $btnSaveMail.Add_Click({
        $mailData = @{
            host = $txtMHost.Text
            port = $txtMPort.Text
            user = $txtMUser.Text
            pass = $txtMPass.Password
            from = $txtMFrom.Text
            to = $txtMTo.Text
            subject = $txtMSubject.Text
            body = $txtMBody.Text
            insecure = [bool]$chkMInsecure.IsChecked
        }
        $mailJson = $mailData | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($mailFile, $mailJson, $utf8NoBom)
        
        if (Test-Path $jobFile) {
            $allJobsStr = [System.IO.File]::ReadAllText($jobFile)
            if (-not [string]::IsNullOrWhiteSpace($allJobsStr)) {
                $allJobs = $allJobsStr | ConvertFrom-Json
                if ($null -ne $allJobs) {
                    foreach ($prop in $allJobs.psobject.properties) {
                        Update-ConfigFile -jName $prop.Name -jobData $prop.Value | Out-Null
                    }
                }
            }
        }
        
        [System.Windows.MessageBox]::Show("Email Settings Saved & All Configs Updated!") | Out-Null
        $MailWindow.Close()
    })
    
    $MailWindow.Owner = $Window
    $MailWindow.ShowDialog() | Out-Null
})

Update-List
$Window.ShowDialog() | Out-Null
