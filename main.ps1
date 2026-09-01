#requires -Version 7.5
<#
.SYNOPSIS
  AmneziaWG Quick Admin GUI
.DESCRIPTION
  Entry point for the AmneziaWG Admin GUI application. Manages you Quick Amnezia WireGuard installation through GUI Interface in Windows for easy deploy for remote access users
.NOTES
  Version:        0.02
  Author:         Andrew Afanasiev
  Date:           02 Sep 2026
  Contacts:       AfanasievAA@yandex.ru

Requires powershell 7.5+ and Putty be installed locally to run.
Install AWG Server Quick stand-alone prior using script from
    wget -O install_amneziawg_en.sh https://raw.githubusercontent.com/bivlked/amneziawg-installer/main/install_amneziawg_en.sh
    chmod +x install_amneziawg_en.sh
    sudo bash ./install_amneziawg_en.sh
Follow instructions. Then edit settings
   sudo nano /root/awg/awgsetup_cfg.init

Then enjoy this GUI for your installation to create access to your LAN for corporate workers. 
#> 

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# === Environment check ===
if ($PSVersionTable.PSVersion.Major -lt 7 -or 
    ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 5)) {
    Write-Host "Requires PowerShell 7.5 or higher. Current version: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# === Load .NET assemblies ===
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

# === Load SSH.NET and BouncyCastle libraries (auto-download if missing) ===
 $sshNetPath = Join-Path $PSScriptRoot "Renci.SshNet.dll"
 $bouncyPath = Join-Path $PSScriptRoot "BouncyCastle.Cryptography.dll"

# Force re-download if any file is missing or too small
 $needDownload = $false
if (-not (Test-Path $sshNetPath) -or -not (Test-Path $bouncyPath)) {
    $needDownload = $true
} else {
    if ((Get-Item $sshNetPath).Length -lt 100000 -or (Get-Item $bouncyPath).Length -lt 100000) {
        $needDownload = $true
    }
}

if ($needDownload) {
    try {
        Write-Host "Downloading SSH.NET and BouncyCastle libraries..."
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # 1. Download SSH.NET (using direct v3-flatcontainer URL to avoid redirects)
        $sshUrl = "https://api.nuget.org/v3-flatcontainer/ssh.net/2024.2.0/ssh.net.2024.2.0.nupkg"
        $sshZipPath = Join-Path $env:TEMP "sshnet.zip"
        Invoke-WebRequest -Uri $sshUrl -OutFile $sshZipPath -UseBasicParsing
        
        $sshZip = [System.IO.Compression.ZipFile]::OpenRead($sshZipPath)
        $sshEntry = $sshZip.Entries | Where-Object { $_.FullName -eq "lib/net8.0/Renci.SshNet.dll" } | Select-Object -First 1
        if ($sshEntry) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($sshEntry, $sshNetPath, $true)
        }
        $sshZip.Dispose()
        Remove-Item $sshZipPath -Force

        # 2. Download BouncyCastle.Cryptography (using direct v3-flatcontainer URL)
        $bouncyUrl = "https://api.nuget.org/v3-flatcontainer/bouncycastle.cryptography/2.3.1/bouncycastle.cryptography.2.3.1.nupkg"
        $bouncyZipPath = Join-Path $env:TEMP "bouncycastle.zip"
        Invoke-WebRequest -Uri $bouncyUrl -OutFile $bouncyZipPath -UseBasicParsing
        
        $bouncyZip = [System.IO.Compression.ZipFile]::OpenRead($bouncyZipPath)
        $bouncyEntry = $bouncyZip.Entries | Where-Object { $_.FullName -eq "lib/net6.0/BouncyCastle.Cryptography.dll" } | Select-Object -First 1
        if ($bouncyEntry) {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($bouncyEntry, $bouncyPath, $true)
        }
        $bouncyZip.Dispose()
        Remove-Item $bouncyZipPath -Force

        # Final check
        if (-not (Test-Path $sshNetPath) -or -not (Test-Path $bouncyPath)) {
            throw "Failed to extract required DLLs."
        }
    }
    catch {
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to download SSH libraries.`n`nError: $($_.Exception.Message)`n`nPlease download Renci.SshNet.dll and BouncyCastle.Cryptography.dll manually.",
            "Critical Error",
            "OK",
            [System.Windows.Forms.MessageBoxIcon]::Error)
        exit 1
    }
}

# Unblock DLLs and load them
Unblock-File -Path $bouncyPath -ErrorAction SilentlyContinue
Unblock-File -Path $sshNetPath -ErrorAction SilentlyContinue
Add-Type -Path $bouncyPath
Add-Type -Path $sshNetPath

# === Import modules ===
$modulePath = Join-Path $PSScriptRoot "modules"
$formPath = Join-Path $PSScriptRoot "forms"

# 1. Localization — MUST be loaded first
. (Join-Path $modulePath "Localization.ps1")

# 2. Classes
. (Join-Path $modulePath "Classes.ps1")

# 3. Functions
. (Join-Path $modulePath "ConfigParser.ps1")

# Forms
. (Join-Path $formPath "MainForm.ps1")
. (Join-Path $formPath "AddClientForm.ps1")
. (Join-Path $formPath "EditClientForm.ps1")
. (Join-Path $formPath "ViewConfigForm.ps1")
. (Join-Path $formPath "ProfileForm.ps1")
. (Join-Path $formPath "StatsForm.ps1")

# === Initialize localization before any UI ===
Initialize-Localization

# === Application context ===
$script:App = @{
    ProfileManager = [ProfileManager]::new()
    Profiles       = @()
    SSHManager     = $null
    ClientManager  = $null
    MainForm       = $null
}

# Load profiles
try {
    $script:App.Profiles = $script:App.ProfileManager.LoadAllProfiles()
}
catch {
    Write-Warning "Failed to load profiles: $($_.Exception.Message)"
    $script:App.Profiles = @()
}

# === Run application ===
try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $mainGui = New-MainForm -AppContext $script:App
    $script:App.MainForm = $mainGui.Form
    $script:MainForm = $mainGui.Form
    
    [System.Windows.Forms.Application]::Run($mainGui.Form)
}
catch {
    Write-Host "Critical error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
    Read-Host "Press Enter to exit"
    exit 1
}
finally {
    # Cleanup
    $script:App.SSHManager = $null
    $script:App.ClientManager = $null
}