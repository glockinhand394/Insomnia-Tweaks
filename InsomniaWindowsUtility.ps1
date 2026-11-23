# Insomnia Tweaks - Windows Utility
# Original WinUtil-inspired implementation. Not affiliated with Chris Titus Tech.
# Windows 11 | PowerShell 5.1+ | WPF
# Run elevated for system-wide actions.

[CmdletBinding()]
param([ValidateSet('Minimal','Standard','Advanced')][string]$Preset)

$ErrorActionPreference = 'Continue'
try { Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms } catch {}
$script:Accent = '#A75ED6'
$script:LogPath = Join-Path $env:TEMP 'InsomniaTweaks.log'
$script:SelectedApps = @{}
$script:AppCatalog = @(
    @{Name='7-Zip';Id='7zip.7zip';Category='Utilities'}, @{Name='Google Chrome';Id='Google.Chrome';Category='Browsers'},
    @{Name='Mozilla Firefox';Id='Mozilla.Firefox';Category='Browsers'}, @{Name='Brave';Id='Brave.Brave';Category='Browsers'},
    @{Name='Microsoft Edge';Id='Microsoft.Edge';Category='Browsers'}, @{Name='Discord';Id='Discord.Discord';Category='Communication'},
    @{Name='Spotify';Id='Spotify.Spotify';Category='Media'}, @{Name='VLC';Id='VideoLAN.VLC';Category='Media'},
    @{Name='OBS Studio';Id='OBSProject.OBSStudio';Category='Media'}, @{Name='Steam';Id='Valve.Steam';Category='Gaming'},
    @{Name='Epic Games Launcher';Id='EpicGames.EpicGamesLauncher';Category='Gaming'}, @{Name='GOG Galaxy';Id='GOG.Galaxy';Category='Gaming'},
    @{Name='Visual Studio Code';Id='Microsoft.VisualStudioCode';Category='Development'}, @{Name='Git';Id='Git.Git';Category='Development'},
    @{Name='Python 3';Id='Python.Python.3.13';Category='Development'}, @{Name='Node.js LTS';Id='OpenJS.NodeJS.LTS';Category='Development'},
    @{Name='GitHub Desktop';Id='GitHub.GitHubDesktop';Category='Development'}, @{Name='Notepad++';Id='Notepad++.Notepad++';Category='Utilities'},
    @{Name='PowerToys';Id='Microsoft.PowerToys';Category='Utilities'}, @{Name='Everything';Id='voidtools.Everything';Category='Utilities'},
    @{Name='ShareX';Id='ShareX.ShareX';Category='Utilities'}, @{Name='Microsoft 365';Id='Microsoft.Office';Category='Productivity'},
    @{Name='LibreOffice';Id='TheDocumentFoundation.LibreOffice';Category='Productivity'}, @{Name='Adobe Acrobat Reader';Id='Adobe.Acrobat.Reader.64-bit';Category='Productivity'},
    @{Name='qBittorrent';Id='qBittorrent.qBittorrent';Category='Internet'}, @{Name='WinSCP';Id='WinSCP.WinSCP';Category='Internet'},
    @{Name='FileZilla';Id='FileZilla.FileZilla';Category='Internet'}, @{Name='OpenVPN Connect';Id='OpenVPNTechnologies.OpenVPNConnect';Category='Internet'},
    @{Name='NVIDIA App';Id='Nvidia.GeForceExperience';Category='Drivers'}, @{Name='AMD Software';Id='AdvancedMicroDevices.AMDSoftware';Category='Drivers'}
)
$script:Tweaks = @(
    @{Name='Create a restore point';Group='Essential';Path='Restore';Value=1;Risk='Safe'},
    @{Name='Enable dark mode';Group='Appearance';Path='Dark';Value=1;Risk='Safe'},
    @{Name='Show file extensions';Group='File Explorer';Path='Extensions';Value=1;Risk='Safe'},
    @{Name='Show hidden files';Group='File Explorer';Path='Hidden';Value=1;Risk='Safe'},
    @{Name='Disable transparency effects';Group='Appearance';Path='Transparency';Value=0;Risk='Safe'},
    @{Name='Disable taskbar widgets';Group='Taskbar';Path='Widgets';Value=0;Risk='Low'},
    @{Name='Disable taskbar search highlights';Group='Taskbar';Path='SearchHighlights';Value=0;Risk='Low'},
    @{Name='Disable consumer suggestions';Group='Privacy';Path='Suggestions';Value=0;Risk='Low'},
    @{Name='Disable activity history';Group='Privacy';Path='Activity';Value=0;Risk='Low'},
    @{Name='Disable delivery optimisation peer sharing';Group='Privacy';Path='Delivery';Value=0;Risk='Low'},
    @{Name='Disable background apps (current user policy)';Group='Performance';Path='Background';Value=0;Risk='Medium'},
    @{Name='Set power plan to High performance';Group='Performance';Path='Power';Value=1;Risk='Medium'},
    @{Name='Disable mouse acceleration';Group='Input';Path='Mouse';Value=0;Risk='Low'},
    @{Name='Enable Game Mode';Group='Gaming';Path='GameMode';Value=1;Risk='Safe'},
    @{Name='Disable Xbox Game Bar captures';Group='Gaming';Path='Captures';Value=0;Risk='Low'}
)

function Test-Admin { $p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function Write-Log([string]$Message) { $line="[$(Get-Date -Format 'HH:mm:ss')] $Message"; Add-Content -LiteralPath $script:LogPath -Value $line; if($script:LogBox){$script:LogBox.AppendText($line+[Environment]::NewLine);$script:LogBox.ScrollToEnd()} }
function Confirm-Run([string]$Message) { return ([System.Windows.MessageBox]::Show($Message,'Insomnia Tweaks','YesNo','Warning') -eq 'Yes') }
function Invoke-Logged([string]$Name,[scriptblock]$Action) { Write-Log "Starting: $Name"; try { & $Action; Write-Log "Completed: $Name" } catch { Write-Log "FAILED: $Name - $($_.Exception.Message)"; [System.Windows.MessageBox]::Show($_.Exception.Message,'Insomnia Tweaks - Error','OK','Error')|Out-Null } }
function Ensure-Winget { if(-not (Get-Command winget.exe -ErrorAction SilentlyContinue)){throw 'Windows Package Manager (winget) was not found. Install or update App Installer from Microsoft Store.'} }
function New-RestorePoint { if(-not (Test-Admin)){Write-Log 'Restore point requires Administrator.';return}; try { Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue; Checkpoint-Computer -Description 'Before Insomnia Tweaks' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop; Write-Log 'Restore point created.' } catch { Write-Log "Restore point unavailable: $($_.Exception.Message)" } }
function Set-Reg([string]$Path,[string]$Name,[object]$Value,[Microsoft.Win32.RegistryValueKind]$Kind=[Microsoft.Win32.RegistryValueKind]::DWord) { if(!(Test-Path $Path)){New-Item -Path $Path -Force|Out-Null}; New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Kind -Force|Out-Null }
function Get-SystemInfo { $os=Get-CimInstance Win32_OperatingSystem; $cpu=(Get-CimInstance Win32_Processor|Select-Object -First 1).Name; $gpu=(Get-CimInstance Win32_VideoController|ForEach-Object Name)-join ', '; $ram=[math]::Round($os.TotalVisibleMemorySize/1MB,1); $d=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$env:SystemDrive'"; return "PC: $env:COMPUTERNAME`r`nOS: $($os.Caption) | Build $($os.BuildNumber)`r`nCPU: $cpu`r`nGPU: $gpu`r`nRAM: $ram GB`r`nDrive: $env:SystemDrive $([math]::Round($d.FreeSpace/1GB,1)) GB free / $([math]::Round($d.Size/1GB,1)) GB`r`nPowerShell: $($PSVersionTable.PSVersion)`r`nAdministrator: $(Test-Admin)" }

# WPF theme and WinUtil-style tabbed layout
[xml]$Xaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Insomnia Tweaks" Height="850" Width="1240" MinHeight="700" MinWidth="980" WindowStartupLocation="CenterScreen" Background="#111014" Foreground="#F5EFF9" FontFamily="Segoe UI">
 <Window.Resources>
  <SolidColorBrush x:Key="Panel" Color="#1B1720"/><SolidColorBrush x:Key="Accent" Color="#A75ED6"/>
  <Style TargetType="Button"><Setter Property="Background" Value="#30243A"/><Setter Property="Foreground" Value="#FFFFFF"/><Setter Property="BorderBrush" Value="#8051A0"/><Setter Property="Padding" Value="13,8"/><Setter Property="Margin" Value="4"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontWeight" Value="SemiBold"/></Style>
  <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#F0E8F5"/><Setter Property="Margin" Value="7,5"/><Setter Property="FontSize" Value="13"/></Style>
  <Style TargetType="TextBox"><Setter Property="Background" Value="#17131B"/><Setter Property="Foreground" Value="#F0E8F5"/><Setter Property="BorderBrush" Value="#493354"/><Setter Property="Padding" Value="8"/></Style>
  <Style TargetType="TabItem"><Setter Property="Foreground" Value="#F5EFF9"/><Setter Property="Background" Value="#211B28"/><Setter Property="Padding" Value="16,11"/><Setter Property="FontWeight" Value="SemiBold"/></Style>
  <Style TargetType="GroupBox"><Setter Property="Foreground" Value="#C58BEA"/><Setter Property="BorderBrush" Value="#493354"/><Setter Property="Margin" Value="5"/><Setter Property="Padding" Value="8"/></Style>
 </Window.Resources>
 <DockPanel>
  <Border DockPanel.Dock="Top" Background="#1B1421" Padding="16"><Grid><Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions><Border Width="48" Height="48" CornerRadius="9" Background="#30243A" Margin="0,0,12,0"><Image Name="Logo" Stretch="Uniform"/></Border><StackPanel Grid.Column="1" VerticalAlignment="Center"><TextBlock Text="INSOMNIA TWEAKS" FontSize="24" FontWeight="Bold" Foreground="#C58BEA"/><TextBlock Text="WINDOWS UTILITY  •  INSTALL  •  TWEAK  •  REPAIR  •  UPDATE" FontSize="10" Foreground="#B8A9C4"/></StackPanel><StackPanel Grid.Column="2" VerticalAlignment="Center" HorizontalAlignment="Right"><TextBlock Name="AdminStatus" Text="Checking permissions" Foreground="#D9C5E8" HorizontalAlignment="Right"/><TextBlock Text="INSOMNIA SERVICES" FontSize="10" Foreground="#A75ED6" HorizontalAlignment="Right"/></StackPanel></Grid></Border>
  <Border DockPanel.Dock="Bottom" Background="#1B1720" Padding="8"><DockPanel><TextBlock Text="Insomnia Tweaks • Review changes before applying. Some actions require Administrator." Foreground="#B8A9C4" VerticalAlignment="Center"/><TextBlock Name="QueueStatus" DockPanel.Dock="Right" Text="Ready" Foreground="#C58BEA" HorizontalAlignment="Right"/></DockPanel></Border>
  <Grid Margin="10"><Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="155"/></Grid.RowDefinitions>
   <TabControl Name="MainTabs" Background="#111014" BorderBrush="#493354">
    <TabItem Header="Install"><Grid Margin="12"><Grid.ColumnDefinitions><ColumnDefinition Width="230"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions><DockPanel Grid.Column="0"><TextBlock DockPanel.Dock="Top" Text="CATEGORIES" Foreground="#C58BEA" FontWeight="Bold" Margin="8"/><ListBox Name="CategoryList" Background="#17131B" Foreground="#F0E8F5" BorderBrush="#493354"/></DockPanel><DockPanel Grid.Column="1" Margin="12,0,0,0"><StackPanel DockPanel.Dock="Top"><TextBlock Text="Application installer" FontSize="22" FontWeight="SemiBold"/><TextBlock Text="Select applications, then install or uninstall them through winget." Foreground="#B8A9C4" Margin="0,3,0,8"/><TextBox Name="AppSearch" Height="34" ToolTip="Search applications"/></StackPanel><ScrollViewer VerticalScrollBarVisibility="Auto" Margin="0,8"><WrapPanel Name="AppsPanel"/></ScrollViewer><WrapPanel DockPanel.Dock="Bottom"><Button Name="SelectAllApps" Content="Select visible"/><Button Name="ClearApps" Content="Clear selection"/><Button Name="InstallApps" Content="Install / Upgrade selected" Background="#63338A"/><Button Name="UninstallApps" Content="Uninstall selected"/></WrapPanel></DockPanel></Grid></TabItem>
    <TabItem Header="Insomnia Twerks"><DockPanel Margin="12"><StackPanel DockPanel.Dock="Top"><TextBlock Text="Windows tweaks" FontSize="22" FontWeight="SemiBold"/><TextBlock Text="Choose a preset or select individual tweaks. Create a restore point before making changes." Foreground="#B8A9C4" Margin="0,3,0,8"/><WrapPanel><Button Name="PresetMinimal" Content="Minimal preset"/><Button Name="PresetStandard" Content="Standard preset"/><Button Name="PresetAdvanced" Content="Advanced preset"/><Button Name="SelectSafe" Content="Select essential"/><Button Name="ClearTweaks" Content="Clear"/></WrapPanel></StackPanel><ScrollViewer VerticalScrollBarVisibility="Auto"><WrapPanel Name="TweaksPanel"/></ScrollViewer><WrapPanel DockPanel.Dock="Bottom"><Button Name="RunTweaks" Content="Run selected tweaks" Background="#63338A"/><Button Name="UndoTweaks" Content="Undo selected tweaks"/><Button Name="RestorePoint" Content="Create restore point"/></WrapPanel></DockPanel></TabItem>
    <TabItem Header="Config"><ScrollViewer><WrapPanel Margin="12"><GroupBox Header="Quick access" Width="350"><WrapPanel><Button Name="OpenSettings" Content="Windows Settings"/><Button Name="OpenControl" Content="Control Panel"/><Button Name="OpenStartup" Content="Startup apps"/><Button Name="OpenStorage" Content="Storage"/><Button Name="OpenPower" Content="Power options"/><Button Name="OpenNetwork" Content="Network settings"/><Button Name="OpenInstalled" Content="Installed apps"/><Button Name="OpenDevice" Content="Device Manager"/><Button Name="OpenTaskMgr" Content="Task Manager"/></WrapPanel></GroupBox><GroupBox Header="Fixes & repair" Width="440"><WrapPanel><Button Name="FixNetwork" Content="Reset network stack"/><Button Name="FixUpdate" Content="Reset Windows Update cache"/><Button Name="FixWinget" Content="Repair winget sources"/><Button Name="RunSFC" Content="SFC /scannow"/><Button Name="RunDISM" Content="DISM RestoreHealth"/><Button Name="FlushDNS" Content="Flush DNS"/></WrapPanel></GroupBox><GroupBox Header="System tools" Width="300"><WrapPanel><Button Name="OpenServices" Content="Services"/><Button Name="OpenEvent" Content="Event Viewer"/><Button Name="OpenDisk" Content="Disk Management"/><Button Name="OpenSystem" Content="System Information"/><Button Name="OpenTerminal" Content="Terminal"/></WrapPanel></GroupBox></WrapPanel></ScrollViewer></TabItem>
    <TabItem Header="Updates"><StackPanel Margin="18"><TextBlock Text="Windows Update" FontSize="22" FontWeight="SemiBold"/><TextBlock Text="Manage update preferences using supported Windows settings and policy controls. Security updates are recommended." Foreground="#B8A9C4" TextWrapping="Wrap" Margin="0,4,0,12"/><GroupBox Header="Update settings" Width="640"><StackPanel><RadioButton Name="UpdateDefault" GroupName="Updates" Content="Default — Windows manages updates normally" IsChecked="True" Margin="8"/><RadioButton Name="UpdateNotify" GroupName="Updates" Content="Notify before download / install (where supported)" Margin="8"/><RadioButton Name="UpdatePause" GroupName="Updates" Content="Pause automatic updates (not recommended)" Margin="8"/></StackPanel></GroupBox><WrapPanel><Button Name="ApplyUpdates" Content="Apply update preference" Background="#63338A"/><Button Name="OpenWU" Content="Open Windows Update"/><Button Name="OpenWUHistory" Content="Update history"/></WrapPanel><TextBlock Text="Note: Windows may override update policies. Keep Windows security updates enabled unless you have a specific reason to change them." Foreground="#B8A9C4" TextWrapping="Wrap" Width="650" Margin="6,16"/></StackPanel></TabItem>
    <TabItem Header="Win11 Creator"><StackPanel Margin="18"><TextBlock Text="Windows 11 Creator" FontSize="22" FontWeight="SemiBold"/><TextBlock Text="Start with an official Windows 11 image. This page provides safe links and local ISO / USB preparation shortcuts; it does not silently modify or deploy Windows images." Foreground="#B8A9C4" TextWrapping="Wrap" Width="760" Margin="0,4,0,14"/><GroupBox Header="Official Microsoft tools" Width="720"><StackPanel><TextBlock Text="Download the Windows 11 ISO or Media Creation Tool directly from Microsoft." Margin="8"/><WrapPanel><Button Name="DownloadISO" Content="Windows 11 download page"/><Button Name="MediaTool" Content="Media Creation Tool"/><Button Name="USBHelp" Content="USB installation guide"/></WrapPanel></StackPanel></GroupBox><GroupBox Header="Local image tools" Width="720"><WrapPanel><Button Name="SelectISO" Content="Select ISO file"/><Button Name="MountISO" Content="Mount selected ISO"/><Button Name="OpenDISM" Content="DISM documentation"/></WrapPanel><TextBlock Name="ISOPath" Text="No ISO selected" Foreground="#B8A9C4" Margin="8"/></GroupBox><TextBlock Text="Advanced image servicing (component removal, unattended setup and custom ISO rebuilding) is not included in this initial release." Foreground="#D7B9E8" TextWrapping="Wrap" Width="720" Margin="8,12"/></StackPanel></TabItem>
    <TabItem Header="System"><DockPanel Margin="14"><StackPanel DockPanel.Dock="Top"><TextBlock Text="System information" FontSize="22" FontWeight="SemiBold"/><WrapPanel><Button Name="RefreshInfo" Content="Refresh"/><Button Name="CopyInfo" Content="Copy details"/></WrapPanel></StackPanel><TextBox Name="InfoBox" IsReadOnly="True" FontFamily="Consolas" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></DockPanel></TabItem>
   </TabControl>
   <GroupBox Grid.Row="1" Header="Activity log" Foreground="#C58BEA" BorderBrush="#493354" Margin="0,8,0,0"><DockPanel><Button Name="ClearLog" DockPanel.Dock="Right" Content="Clear log" VerticalAlignment="Top"/><TextBox Name="LogBox" IsReadOnly="True" BorderThickness="0" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/></DockPanel></GroupBox>
  </Grid>
 </DockPanel>
</Window>
'@

$reader=New-Object System.Xml.XmlNodeReader $Xaml
$script:Window=[Windows.Markup.XamlReader]::Load($reader)
function Get-Control([string]$Name){$script:Window.FindName($Name)}
$script:LogBox=Get-Control 'LogBox'
$script:Window.Add_Loaded({
    $admin=Test-Admin; (Get-Control 'AdminStatus').Text=if($admin){'Administrator: Yes'}else{'Administrator: No — some actions disabled'}
    # Prefer the repository's local insomnia.png. For public repos, try the raw GitHub asset as a fallback.
    $logoPath=Join-Path (Get-Location).Path 'insomnia.png'
    if($PSScriptRoot){$candidate=Join-Path $PSScriptRoot 'insomnia.png';if(Test-Path $candidate){$logoPath=$candidate}}
    try { if(Test-Path $logoPath){$bmp=New-Object Windows.Media.Imaging.BitmapImage; $bmp.BeginInit();$bmp.UriSource=[Uri]$logoPath;$bmp.CacheOption='OnLoad';$bmp.EndInit();(Get-Control 'Logo').Source=$bmp;$script:Window.Icon=$bmp} else { $uri='https://raw.githubusercontent.com/glockinhand394/Insomnia-Tweaks/main/insomnia.png';$bmp=New-Object Windows.Media.Imaging.BitmapImage;$bmp.BeginInit();$bmp.UriSource=[Uri]$uri;$bmp.CacheOption='OnLoad';$bmp.EndInit();(Get-Control 'Logo').Source=$bmp;$script:Window.Icon=$bmp } } catch { Write-Log 'Logo not loaded. Put insomnia.png beside the PS1 file (or at repository root).' }
    Write-Log 'Insomnia Tweaks started.'; if(!$admin){Write-Log 'Tip: relaunch PowerShell as Administrator for system-wide actions.'}
    (Get-Control 'InfoBox').Text=Get-SystemInfo
})

# App browser
$categories=@('All')+@($script:AppCatalog.Category|Sort-Object -Unique)
$cat=Get-Control 'CategoryList'; foreach($c in $categories){[void]$cat.Items.Add($c)};$cat.SelectedIndex=0
function Render-Apps {
    $panel=Get-Control 'AppsPanel';$panel.Children.Clear();$category=[string](Get-Control 'CategoryList').SelectedItem;$search=[string](Get-Control 'AppSearch').Text
    foreach($app in $script:AppCatalog){if(($category -eq 'All' -or $app.Category -eq $category) -and ($app.Name -like "*$search*" -or $app.Id -like "*$search*")){$cb=New-Object Windows.Controls.CheckBox;$cb.Content="$($app.Name)  [$($app.Category)]";$cb.Tag=$app;$cb.Width=245;$cb.ToolTip=$app.Id;$cb.IsChecked=[bool]$script:SelectedApps[$app.Id];$cb.Add_Checked({$a=$this.Tag;$script:SelectedApps[$a.Id]=$true});$cb.Add_Unchecked({$a=$this.Tag;$script:SelectedApps.Remove($a.Id)});[void]$panel.Children.Add($cb)}}
}
$cat.Add_SelectionChanged({Render-Apps});(Get-Control 'AppSearch').Add_TextChanged({Render-Apps});Render-Apps
(Get-Control 'SelectAllApps').Add_Click({foreach($c in (Get-Control 'AppsPanel').Children){$c.IsChecked=$true}})
(Get-Control 'ClearApps').Add_Click({$script:SelectedApps.Clear();Render-Apps})
(Get-Control 'InstallApps').Add_Click({if(!$script:SelectedApps.Count){return};if(!(Confirm-Run "Install or upgrade $($script:SelectedApps.Count) selected applications using winget?")){return};Invoke-Logged 'Install selected apps' {Ensure-Winget;foreach($id in @($script:SelectedApps.Keys)){Write-Log "Installing $id";& winget install --id $id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1|ForEach-Object{Write-Log ([string]$_)} }}})
(Get-Control 'UninstallApps').Add_Click({if(!$script:SelectedApps.Count){return};if(!(Confirm-Run "Uninstall $($script:SelectedApps.Count) selected applications? This may remove app data.")){return};Invoke-Logged 'Uninstall selected apps' {Ensure-Winget;foreach($id in @($script:SelectedApps.Keys)){Write-Log "Uninstalling $id";& winget uninstall --id $id --exact --silent 2>&1|ForEach-Object{Write-Log ([string]$_)} }}})

# Tweak browser and reversible actions
$tp=Get-Control 'TweaksPanel';$script:TweakChecks=@{}
foreach($group in ($script:Tweaks.Group|Sort-Object -Unique)){$gb=New-Object Windows.Controls.GroupBox;$gb.Header=$group;$gb.Width=330;$stack=New-Object Windows.Controls.StackPanel;foreach($t in ($script:Tweaks|Where-Object Group -eq $group)){$cb=New-Object Windows.Controls.CheckBox;$cb.Content=$t.Name;$cb.Tag=$t;$cb.ToolTip="Risk: $($t.Risk)";$script:TweakChecks[$t.Path]=$cb;[void]$stack.Children.Add($cb)};$gb.Content=$stack;[void]$tp.Children.Add($gb)}
function Set-Preset([string]$Name){foreach($key in $script:TweakChecks.Keys){$script:TweakChecks[$key].IsChecked=$false};$paths=switch($Name){'Minimal'{@('Restore','Dark','Extensions','GameMode')} 'Standard'{@('Restore','Dark','Extensions','Hidden','Widgets','Suggestions','GameMode')} 'Advanced'{@('Restore','Dark','Extensions','Hidden','Transparency','Widgets','SearchHighlights','Suggestions','Activity','Delivery','Background','Power','Mouse','GameMode','Captures')}};foreach($p in $paths){if($script:TweakChecks.ContainsKey($p)){$script:TweakChecks[$p].IsChecked=$true}};Write-Log "$Name preset selected."}
(Get-Control 'PresetMinimal').Add_Click({Set-Preset Minimal});(Get-Control 'PresetStandard').Add_Click({Set-Preset Standard});(Get-Control 'PresetAdvanced').Add_Click({Set-Preset Advanced});(Get-Control 'SelectSafe').Add_Click({Set-Preset Minimal});(Get-Control 'ClearTweaks').Add_Click({foreach($c in $script:TweakChecks.Values){$c.IsChecked=$false}})
if($Preset){Set-Preset $Preset}
function Invoke-Tweak([string]$Path,[bool]$Undo){$u=$Undo
 switch($Path){
  'Restore'{if(!$u){New-RestorePoint}}
  'Dark'{$v=if($u){0}else{1};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' AppsUseLightTheme $v;Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' SystemUsesLightTheme $v}
  'Extensions'{$v=if($u){1}else{0};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' HideFileExt $v}
  'Hidden'{$v=if($u){2}else{1};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' Hidden $v}
  'Transparency'{$v=if($u){1}else{0};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' EnableTransparency $v}
  'Widgets'{$v=if($u){1}else{0};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' TaskbarDa $v}
  'SearchHighlights'{$v=if($u){1}else{0};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' IsDynamicSearchBoxEnabled $v}
  'Suggestions'{$v=if($u){0}else{1};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' SystemPaneSuggestionsEnabled $v}
  'Activity'{$v=if($u){1}else{0};Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' EnableActivityFeed $v}
  'Delivery'{$v=if($u){1}else{0};Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' DODownloadMode $(if($u){1}else{0})}
  'Background'{$v=if($u){0}else{2};Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' GlobalUserDisabled $v}
  'Power'{if($u){& powercfg /setactive SCHEME_BALANCED}else{& powercfg /setactive SCHEME_MIN}}
  'Mouse'{if($u){Set-Reg 'HKCU:\Control Panel\Mouse' MouseSpeed '1' String;Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold1 '6' String;Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold2 '10' String}else{Set-Reg 'HKCU:\Control Panel\Mouse' MouseSpeed '0' String;Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold1 '0' String;Set-Reg 'HKCU:\Control Panel\Mouse' MouseThreshold2 '0' String}}
  'GameMode'{$v=if($u){0}else{1};Set-Reg 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled $v;Set-Reg 'HKCU:\Software\Microsoft\GameBar' AllowAutoGameMode $v}
  'Captures'{$v=if($u){1}else{0};Set-Reg 'HKCU:\System\GameConfigStore' GameDVR_Enabled $v}
 }
}
(Get-Control 'RunTweaks').Add_Click({$chosen=@($script:TweakChecks.Values|Where-Object IsChecked);if(!$chosen.Count){return};if(!(Confirm-Run "Apply $($chosen.Count) selected tweaks? A restore point will be attempted first.")){return};Invoke-Logged 'Apply tweaks' {if(Test-Admin){New-RestorePoint};foreach($cb in $chosen){$t=$cb.Tag;Invoke-Tweak $t.Path $false;Write-Log "Applied $($t.Name)"};Write-Log 'Some changes may require sign-out or restart.'}})
(Get-Control 'UndoTweaks').Add_Click({$chosen=@($script:TweakChecks.Values|Where-Object IsChecked);if(!$chosen.Count){return};if(!(Confirm-Run "Undo $($chosen.Count) selected tweaks and restore common defaults?")){return};Invoke-Logged 'Undo tweaks' {foreach($cb in $chosen){$t=$cb.Tag;Invoke-Tweak $t.Path $true;Write-Log "Reverted $($t.Name)"}}})
(Get-Control 'RestorePoint').Add_Click({Invoke-Logged 'Create restore point' {New-RestorePoint}})

# Config shortcuts
$script:Shortcuts=@{OpenSettings='ms-settings:';OpenControl='control.exe';OpenStartup='ms-settings:startupapps';OpenStorage='ms-settings:storagesense';OpenPower='powercfg.cpl';OpenNetwork='ms-settings:network-status';OpenInstalled='ms-settings:appsfeatures';OpenDevice='devmgmt.msc';OpenTaskMgr='taskmgr.exe';OpenServices='services.msc';OpenEvent='eventvwr.msc';OpenDisk='diskmgmt.msc';OpenSystem='msinfo32.exe';OpenTerminal='wt.exe'}
foreach($n in $script:Shortcuts.Keys){$controlName=$n;$targetPath=$script:Shortcuts[$n];(Get-Control $controlName).Add_Click(({Start-Process $targetPath -ErrorAction SilentlyContinue}).GetNewClosure())}
(Get-Control 'RunSFC').Add_Click({if(Confirm-Run 'Run System File Checker? This may take a while.'){Invoke-Logged 'SFC scan' {Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','sfc /scannow'}}})
(Get-Control 'RunDISM').Add_Click({if(Confirm-Run 'Run DISM RestoreHealth? This may take a while and requires internet access in some cases.'){Invoke-Logged 'DISM repair' {Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','DISM /Online /Cleanup-Image /RestoreHealth'}}})
(Get-Control 'FlushDNS').Add_Click({Invoke-Logged 'Flush DNS' {Clear-DnsClientCache;Write-Log 'DNS cache cleared.'}})
(Get-Control 'FixNetwork').Add_Click({if(Confirm-Run 'Reset Winsock and TCP/IP? A restart may be required.'){Invoke-Logged 'Network reset' {Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','netsh winsock reset; netsh int ip reset'}}})
(Get-Control 'FixUpdate').Add_Click({if(Confirm-Run 'Stop Windows Update services and rename the SoftwareDistribution cache? Windows will recreate it.'){Invoke-Logged 'Reset Windows Update cache' {Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoExit','-Command','Stop-Service wuauserv,bits -Force; Rename-Item $env:windir\SoftwareDistribution SoftwareDistribution.old -ErrorAction SilentlyContinue; Start-Service bits,wuauserv'}}})
(Get-Control 'FixWinget').Add_Click({Invoke-Logged 'Repair winget sources' {Ensure-Winget;& winget source reset --force;& winget source update}})

# Update controls
(Get-Control 'ApplyUpdates').Add_Click({$choice=if((Get-Control 'UpdatePause').IsChecked){'pause'}elseif((Get-Control 'UpdateNotify').IsChecked){'notify'}else{'default'};if($choice -eq 'pause'){[System.Windows.MessageBox]::Show('Pausing updates can leave this PC exposed to security vulnerabilities. Use Windows Settings to pause updates for a limited period.','Insomnia Tweaks','OK','Warning')|Out-Null;Start-Process 'ms-settings:windowsupdate'}elseif($choice -eq 'notify'){if(Confirm-Run 'Set the policy to notify before download/install? This policy may not apply on every Windows edition.'){Invoke-Logged 'Set update notification policy' {Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' AUOptions 2}}}else{Invoke-Logged 'Restore default update policy' {Remove-Item 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Recurse -Force -ErrorAction SilentlyContinue;Write-Log 'Removed Insomnia-managed AU policy values.'}}})
(Get-Control 'OpenWU').Add_Click({Start-Process 'ms-settings:windowsupdate'});(Get-Control 'OpenWUHistory').Add_Click({Start-Process 'ms-settings:windowsupdate-history'})

# Windows image links and ISO mounting
(Get-Control 'DownloadISO').Add_Click({Start-Process 'https://www.microsoft.com/software-download/windows11'});(Get-Control 'MediaTool').Add_Click({Start-Process 'https://www.microsoft.com/software-download/windows11'});(Get-Control 'USBHelp').Add_Click({Start-Process 'https://support.microsoft.com/windows/create-installation-media-for-windows'})
$script:SelectedISO=$null
(Get-Control 'SelectISO').Add_Click({$dlg=New-Object Microsoft.Win32.OpenFileDialog;$dlg.Filter='Windows ISO (*.iso)|*.iso';if($dlg.ShowDialog()){$script:SelectedISO=$dlg.FileName;(Get-Control 'ISOPath').Text=$dlg.FileName}})
(Get-Control 'MountISO').Add_Click({if($script:SelectedISO){Invoke-Logged 'Mount ISO' {Mount-DiskImage -ImagePath $script:SelectedISO -ErrorAction Stop|Out-Null;Write-Log 'ISO mounted.'}}})
(Get-Control 'OpenDISM').Add_Click({Start-Process 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/what-is-dism'})

# System and log
(Get-Control 'RefreshInfo').Add_Click({(Get-Control 'InfoBox').Text=Get-SystemInfo;Write-Log 'System information refreshed.'})
(Get-Control 'CopyInfo').Add_Click({[System.Windows.Clipboard]::SetText((Get-Control 'InfoBox').Text);Write-Log 'System information copied.'})
(Get-Control 'ClearLog').Add_Click({$script:LogBox.Clear();Set-Content -LiteralPath $script:LogPath -Value ''})

Write-Log 'Ready. Select a tab to begin.'
[void]$script:Window.ShowDialog()
