# Insomnia Windows Utility - original PowerShell toolkit
# Windows 10/11 | PowerShell 5.1+ | WPF interface
# Run: irm https://YOUR-RAW-URL/InsomniaWindowsUtility.ps1 | iex

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$script:LogPath = Join-Path $env:TEMP 'InsomniaWindowsUtility.log'

function Write-Log([string]$Message) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    Add-Content -LiteralPath $script:LogPath -Value $line
    if ($script:LogBox) { $script:LogBox.AppendText($line + [Environment]::NewLine); $script:LogBox.ScrollToEnd() }
}
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Confirm-Action([string]$Message) {
    return ([System.Windows.MessageBox]::Show($Message,'Insomnia Windows Utility','YesNo','Warning') -eq 'Yes')
}
function Invoke-Logged([string]$Name,[scriptblock]$Action) {
    Write-Log "Starting $Name"
    try { & $Action; Write-Log "Finished $Name" }
    catch { Write-Log "ERROR: $($_.Exception.Message)"; [System.Windows.MessageBox]::Show($_.Exception.Message,'Insomnia - Error') | Out-Null }
}
function Set-Dword([string]$Path,[string]$Name,[int]$Value) {
    if (!(Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
}
function New-InsomniaRestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Before Insomnia Utility changes' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log 'Restore point created.'
    } catch { Write-Log "Restore point could not be created: $($_.Exception.Message)" }
}
function Get-SystemInfoText {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
    $gpu = (Get-CimInstance Win32_VideoController | ForEach-Object Name) -join ', '
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB,1)
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"
    $free = [math]::Round($disk.FreeSpace / 1GB,1); $size = [math]::Round($disk.Size / 1GB,1)
    @"
Windows : $($os.Caption) (Build $($os.BuildNumber))
CPU     : $cpu
GPU     : $gpu
RAM     : $ram GB
Drive   : $env:SystemDrive - $free GB free of $size GB
PowerShell: $($PSVersionTable.PSVersion)
Admin   : $(Test-Admin)
"@
}
function Install-WingetPackage([string]$Id) {
    if (!(Get-Command winget.exe -ErrorAction SilentlyContinue)) { throw 'winget is missing. Install Microsoft App Installer first.' }
    & winget install --id $Id --exact --source winget --accept-package-agreements --accept-source-agreements
}

[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Insomnia Windows Utility" Height="790" Width="1120" MinHeight="650" MinWidth="900" WindowStartupLocation="CenterScreen" Background="#111014" Foreground="#F3EDF7" FontFamily="Segoe UI">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#30243A"/><Setter Property="Foreground" Value="White"/><Setter Property="BorderBrush" Value="#8051A0"/><Setter Property="Padding" Value="13,8"/><Setter Property="Margin" Value="4"/><Setter Property="Cursor" Value="Hand"/></Style>
  <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F3EDF7"/><Setter Property="Margin" Value="8,7"/><Setter Property="FontSize" Value="13"/></Style>
  <Style TargetType="TabItem"><Setter Property="Foreground" Value="#F3EDF7"/><Setter Property="Background" Value="#211B28"/><Setter Property="Padding" Value="14,9"/></Style>
 </Window.Resources>
 <DockPanel>
  <Border DockPanel.Dock="Top" Background="#1B1421" Padding="18"><Grid><Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><StackPanel><TextBlock Text="🌙 INSOMNIA" FontSize="26" FontWeight="Bold" Foreground="#C58BEA"/><TextBlock Text="WINDOWS UTILITY  •  TWEAKS  •  REPAIR  •  INSTALL" FontSize="10" Foreground="#B8A9C4"/></StackPanel><StackPanel Grid.Column="1" HorizontalAlignment="Right"><TextBlock Name="AdminStatus" Text="Checking permissions" Foreground="#D9C5E8"/><TextBlock Text="INSOMNIA SERVICES" FontSize="10" Foreground="#A75ED6" HorizontalAlignment="Right"/></StackPanel></Grid></Border>
  <Border DockPanel.Dock="Bottom" Background="#1B1720" Padding="8"><TextBlock Text="Review each selection before applying changes. Some actions require Administrator." Foreground="#B8A9C4"/></Border>
  <Grid Margin="12"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="145"/></Grid.RowDefinitions>
   <TabControl Background="#111014" BorderBrush="#493354">
    <TabItem Header="Install"><ScrollViewer><StackPanel Margin="14"><TextBlock Text="Install applications" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><TextBlock Text="Choose applications to install with Windows Package Manager (winget)." Foreground="#B7AABD" Margin="4"/><WrapPanel Name="AppsPanel"/><Button Name="InstallApps" Content="Install selected" HorizontalAlignment="Left" Margin="4,12"/></StackPanel></ScrollViewer></TabItem>
    <TabItem Header="Tweaks"><ScrollViewer><StackPanel Margin="14"><TextBlock Text="Windows tweaks" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><TextBlock Text="Optional current-user settings. A restore point is attempted first." Foreground="#B7AABD" Margin="4"/><CheckBox Name="DarkMode" Content="Enable Windows and app dark mode"/><CheckBox Name="Transparency" Content="Disable transparency effects"/><CheckBox Name="Extensions" Content="Show file extensions"/><CheckBox Name="Widgets" Content="Hide taskbar widgets"/><CheckBox Name="Chat" Content="Hide Chat / Meet Now taskbar button (where supported)"/><CheckBox Name="BackgroundApps" Content="Restrict background apps (current user policy)"/><Button Name="ApplyTweaks" Content="Apply selected tweaks" HorizontalAlignment="Left"/></StackPanel></ScrollViewer></TabItem>
    <TabItem Header="Config"><StackPanel Margin="16"><TextBlock Text="Windows configuration" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><WrapPanel><Button Name="Settings" Content="Windows Settings"/><Button Name="Startup" Content="Startup apps"/><Button Name="Storage" Content="Storage"/><Button Name="Power" Content="Power options"/><Button Name="Network" Content="Network"/><Button Name="Apps" Content="Installed apps"/></WrapPanel></StackPanel></TabItem>
    <TabItem Header="Updates"><StackPanel Margin="16"><TextBlock Text="Windows Update" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><TextBlock Text="Open Microsoft's Windows Update page. Insomnia does not turn off security updates." Foreground="#B7AABD" TextWrapping="Wrap" Margin="4"/><Button Name="CheckUpdates" Content="Open Windows Update" HorizontalAlignment="Left"/></StackPanel></TabItem>
    <TabItem Header="Repair"><StackPanel Margin="16"><TextBlock Text="System repair" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><TextBlock Text="Built-in Windows repair tools. These may take several minutes." Foreground="#B7AABD" Margin="4"/><WrapPanel><Button Name="SFC" Content="SFC /scannow"/><Button Name="DISM" Content="DISM RestoreHealth"/><Button Name="FlushDNS" Content="Flush DNS"/><Button Name="Winsock" Content="Reset Winsock"/></WrapPanel></StackPanel></TabItem>
    <TabItem Header="Cleanup"><StackPanel Margin="16"><TextBlock Text="Cleanup" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><TextBlock Text="Removes contents of your own TEMP folder only. Files in use are skipped." Foreground="#B7AABD" Margin="4"/><Button Name="CleanTemp" Content="Clean user temporary files" HorizontalAlignment="Left"/></StackPanel></TabItem>
    <TabItem Header="Gaming"><StackPanel Margin="16"><TextBlock Text="Gaming" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,10"/><CheckBox Name="GameMode" Content="Enable Windows Game Mode"/><Button Name="ApplyGameMode" Content="Apply Game Mode setting" HorizontalAlignment="Left"/><WrapPanel><Button Name="GameBar" Content="Game Bar settings"/><Button Name="Graphics" Content="Graphics settings"/><Button Name="GameSettings" Content="Game Mode settings"/></WrapPanel></StackPanel></TabItem>
    <TabItem Header="System Info"><DockPanel Margin="14"><StackPanel DockPanel.Dock="Top"><TextBlock Text="System information" FontSize="21" FontWeight="SemiBold" Margin="4,4,4,8"/><WrapPanel><Button Name="RefreshInfo" Content="Refresh"/><Button Name="CopyInfo" Content="Copy details"/></WrapPanel></StackPanel><TextBox Name="InfoBox" Background="#17131B" Foreground="#E8DDF0" BorderBrush="#493354" FontFamily="Consolas" Padding="12" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></DockPanel></TabItem>
   </TabControl>
   <GroupBox Grid.Row="1" Header="Activity log" Foreground="#C58BEA" BorderBrush="#493354" Margin="0,9,0,0"><TextBox Name="LogBox" Background="#17131B" Foreground="#D5C9DE" BorderThickness="0" FontFamily="Consolas" FontSize="11" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></GroupBox>
  </Grid>
 </DockPanel>
</Window>
'@

$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)
$ControlNames = 'AdminStatus AppsPanel InstallApps DarkMode Transparency Extensions Widgets Chat BackgroundApps ApplyTweaks Settings Startup Storage Power Network Apps CheckUpdates SFC DISM FlushDNS Winsock CleanTemp GameMode ApplyGameMode GameBar Graphics GameSettings RefreshInfo CopyInfo InfoBox LogBox'
foreach ($n in $ControlNames.Split(' ')) { Set-Variable -Name $n -Value $Window.FindName($n) -Scope Script }
$script:LogBox = $LogBox
$AdminStatus.Text = if (Test-Admin) { 'Administrator: Yes' } else { 'Administrator: No - some actions need elevation' }

$PackageList = @(
 @{Name='7-Zip';Id='7zip.7zip'}, @{Name='Google Chrome';Id='Google.Chrome'}, @{Name='Mozilla Firefox';Id='Mozilla.Firefox'},
 @{Name='VLC';Id='VideoLAN.VLC'}, @{Name='Discord';Id='Discord.Discord'}, @{Name='Spotify';Id='Spotify.Spotify'},
 @{Name='Visual Studio Code';Id='Microsoft.VisualStudioCode'}, @{Name='Notepad++';Id='Notepad++.Notepad++'},
 @{Name='Steam';Id='Valve.Steam'}, @{Name='PowerToys';Id='Microsoft.PowerToys'}, @{Name='ShareX';Id='ShareX.ShareX'},
 @{Name='Everything';Id='voidtools.Everything'}, @{Name='Git';Id='Git.Git'}, @{Name='Python 3';Id='Python.Python.3.12'}
)
$script:AppChecks = @()
foreach ($app in $PackageList) {
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Content = $app.Name; $check.Tag = $app.Id; $check.Width = 190
    $AppsPanel.Children.Add($check) | Out-Null; $script:AppChecks += $check
}

$InstallApps.Add_Click({
    $chosen = @($script:AppChecks | Where-Object IsChecked)
    if (!$chosen.Count) { [System.Windows.MessageBox]::Show('Select at least one app.') | Out-Null; return }
    if (!(Confirm-Action "Install $($chosen.Count) selected application(s) using winget?")) { return }
    Invoke-Logged 'App installation' { foreach ($app in $chosen) { Write-Log "Installing $($app.Content)"; Install-WingetPackage $app.Tag } }
})
$ApplyTweaks.Add_Click({
    $selected = @($DarkMode.IsChecked,$Transparency.IsChecked,$Extensions.IsChecked,$Widgets.IsChecked,$Chat.IsChecked,$BackgroundApps.IsChecked)
    if ($selected -notcontains $true) { [System.Windows.MessageBox]::Show('Select at least one tweak.') | Out-Null; return }
    if (!(Confirm-Action 'Apply the selected registry settings? A restore point will be attempted.')) { return }
    Invoke-Logged 'Windows tweaks' {
        New-InsomniaRestorePoint
        $p='HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        if ($DarkMode.IsChecked) { Set-Dword $p AppsUseLightTheme 0; Set-Dword $p SystemUsesLightTheme 0 }
        if ($Transparency.IsChecked) { Set-Dword $p EnableTransparency 0 }
        $e='HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if ($Extensions.IsChecked) { Set-Dword $e HideFileExt 0 }
        if ($Widgets.IsChecked) { Set-Dword $e TaskbarDa 0 }
        if ($Chat.IsChecked) { Set-Dword $e TaskbarMn 0 }
        if ($BackgroundApps.IsChecked) { Set-Dword 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' GlobalUserDisabled 1 }
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Process explorer.exe
    }
})
$Settings.Add_Click({Start-Process 'ms-settings:'}); $Startup.Add_Click({Start-Process 'ms-settings:startupapps'})
$Storage.Add_Click({Start-Process 'ms-settings:storagesense'}); $Power.Add_Click({Start-Process 'powercfg.cpl'})
$Network.Add_Click({Start-Process 'ms-settings:network-status'}); $Apps.Add_Click({Start-Process 'ms-settings:appsfeatures'})
$CheckUpdates.Add_Click({Start-Process 'ms-settings:windowsupdate'})
$GameBar.Add_Click({Start-Process 'ms-settings:gaming-gamebar'}); $Graphics.Add_Click({Start-Process 'ms-settings:display-graphics'}); $GameSettings.Add_Click({Start-Process 'ms-settings:gaming-gamemode'})
$SFC.Add_Click({ if (Confirm-Action 'Run System File Checker?') { Invoke-Logged 'SFC scan' { Start-Process cmd.exe -ArgumentList '/c sfc /scannow' -Verb RunAs -Wait } } })
$DISM.Add_Click({ if (Confirm-Action 'Run DISM RestoreHealth? This may take a while.') { Invoke-Logged 'DISM repair' { Start-Process cmd.exe -ArgumentList '/c DISM /Online /Cleanup-Image /RestoreHealth' -Verb RunAs -Wait } } })
$FlushDNS.Add_Click({Invoke-Logged 'Flush DNS cache' {Start-Process ipconfig.exe -ArgumentList '/flushdns' -Wait -NoNewWindow}})
$Winsock.Add_Click({if (Confirm-Action 'Reset Winsock? A restart may be required.') {Invoke-Logged 'Winsock reset' {Start-Process netsh.exe -ArgumentList 'winsock reset' -Verb RunAs -Wait}}})
$CleanTemp.Add_Click({
    if (Confirm-Action "Delete accessible files in $env:TEMP? Files currently in use will be skipped.") {
        Invoke-Logged 'Temporary file cleanup' {Get-ChildItem -LiteralPath $env:TEMP -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "Cleaned user TEMP folder: $env:TEMP"}
    }
})
$ApplyGameMode.Add_Click({Invoke-Logged 'Game Mode setting' {Set-Dword 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled ([int][bool]$GameMode.IsChecked)}})
$RefreshInfo.Add_Click({$InfoBox.Text=Get-SystemInfoText})
$CopyInfo.Add_Click({[Windows.Clipboard]::SetText($InfoBox.Text);Write-Log 'System information copied to clipboard.'})
$InfoBox.Text = Get-SystemInfoText
Write-Log 'Insomnia Windows Utility loaded.'
if (!(Test-Admin)) { Write-Log 'Some repair and system-wide actions will request elevation when needed.' }
$null = $Window.ShowDialog()
