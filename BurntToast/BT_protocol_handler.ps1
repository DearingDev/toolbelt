# This script is designed to be run as an administrator or as the SYSTEM account.

$ModuleName = 'BurntToast'
$MinimumVersion = '0.8.5'

try {
    # Check if the module is installed and at least the minimum version.
    $InstalledModule = Get-InstalledModule -Name $ModuleName -ErrorAction Stop
    if ($InstalledModule.Version -lt $MinimumVersion) {
        Write-Warning "BurntToast module is installed, but version ($($InstalledModule.Version)) is older than the minimum required ($MinimumVersion).  Consider updating."
    }
}
catch {
    Write-Warning "BurntToast module not found. Attempting to install..."
    # Check for NuGet provider, install if missing
    if ( -not ( Get-PackageProvider -ListAvailable | Where-Object Name -eq "Nuget" ) ) {
        Write-Warning "NuGet provider not found. Installing..."
        try {
            Install-PackageProvider -Name NuGet -Force -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to install NuGet provider: $($_.Exception.Message)"
            exit 1  # Exit the script if NuGet provider installation fails
        }
    }

    # Install the module
    try {
        Install-Module -Name $ModuleName -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to install BurntToast module: $($_.Exception.Message)"
        exit 1 # Exit the script if module installation fails
    }
}


# Import the module
try {
    Import-Module -Name $ModuleName -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import BurntToast module: $($_.Exception.Message)"
    exit 1 # Exit the script if module import fails
}


# Checking if ToastReboot:// protocol handler is present
try {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
}
catch {
    Write-Error "Failed to create HKCR PSDrive: $($_.Exception.Message)"
    exit 1
}

$ProtocolHandler = Get-Item 'HKCR:\ToastReboot' -ErrorAction SilentlyContinue

if (-not $ProtocolHandler) {
    # Create handler for reboot
    try {
        New-Item -Path 'HKCR:\ToastReboot' -ItemType Directory -Force -ErrorAction Stop
        Set-ItemProperty -Path 'HKCR:\ToastReboot' -Name '(Default)' -Value 'url:ToastReboot' -Force -ErrorAction Stop
        Set-ItemProperty -Path 'HKCR:\ToastReboot' -Name 'URL Protocol' -Value '' -Force -ErrorAction Stop
        New-ItemProperty -Path 'HKCR:\ToastReboot' -Name 'EditFlags' -Value 2162688 -PropertyType DWord -Force -ErrorAction Stop
        New-Item -Path 'HKCR:\ToastReboot\Shell\Open\command' -ItemType Directory -Force -ErrorAction Stop
        Set-ItemProperty -Path 'HKCR:\ToastReboot\Shell\Open\command' -Name '(Default)' -Value "C:\Windows\System32\shutdown.exe -r -t 30" -Force -ErrorAction Stop
        Write-Host "ToastReboot protocol handler created."
    }
    catch {
        Write-Error "Failed to create ToastReboot protocol handler: $($_.Exception.Message)"
        exit 1
    }
}