#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Automates the uninstallation of existing Visual Studio instances and the installation of a specific version of Visual Studio Build Tools.
.DESCRIPTION
    This script is designed for use in GitHub Actions CI environments on Windows runners. It performs the following actions:
    1. Uninstalls all existing versions of Visual Studio to ensure a clean environment.
    2. Downloads and installs a specified version of Visual Studio Build Tools (2017, 2019, or 2022).
    3. Adds the necessary Visual Studio directories to the system PATH environment variable.
.PARAMETER VSVersion
    Specifies the version of Visual Studio Build Tools to install.
    Valid values are "2017", "2019", and "2022". The default is "2022".
.EXAMPLE
    .
\install_vs.ps1 -VSVersion 2019
    This command will uninstall any existing Visual Studio installations and then install Visual Studio Build Tools 2019.
#>
param(
    [ValidateSet("2017", "2019", "2022")]
    [string]$VSVersion = "2022"
)

function Uninstall-OldVS {
    Write-Host "--- Searching for existing Visual Studio installations to uninstall ---"
    $vsInstallerPath = "${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\Installer\\vs_installer.exe"

    if (Test-Path $vsInstallerPath) {
        $installations = & "${env:ProgramFiles(x86)}\\Microsoft Visual Studio\\Installer\\vswhere.exe" -all -property installationPath
        foreach ($inst in $installations) {
            if (Test-Path $inst) {
                Write-Host "Uninstalling Visual Studio from: $inst"
                $proc = Start-Process -FilePath $vsInstallerPath -ArgumentList "uninstall --path `"$inst`" --quiet --force --norestart" -Wait -PassThru
                if ($proc.ExitCode -ne 0) {
                    Write-Error "Failed to uninstall Visual Studio at $inst. Exit code: $($proc.ExitCode)"
                    # We can choose to exit here, but for CI it might be better to continue
                }
            }
        }
    } else {
        Write-Host "vs_installer.exe not found. Skipping uninstallation."
    }
    Write-Host "--- Finished uninstalling old Visual Studio versions ---"
}

function Install-VS {
    param(
        [string]$Version
    )

    Write-Host "--- Starting installation of Visual Studio Build Tools $Version ---"
    $vsBootstrapperUrl = ""
    $vsComponents = @(
        "Microsoft.VisualStudio.Workload.VCTools",
        "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
        "Microsoft.VisualStudio.Component.Windows10SDK.19041" # A common SDK, adjust if needed
    )

    switch ($Version) {
        "2017" { 
            $vsBootstrapperUrl = "https://aka.ms/vs/15/release/vs_buildtools.exe"
            # For VS 2017, a specific SDK might be needed depending on the project
            $vsComponents += "Microsoft.VisualStudio.Component.Windows10SDK.17763"
        }
        "2019" { 
            $vsBootstrapperUrl = "https://aka.ms/vs/16/release/vs_buildtools.exe" 
        }
        "2022" { 
            $vsBootstrapperUrl = "https://aka.ms/vs/17/release/vs_buildtools.exe" 
            $vsComponents += "Microsoft.VisualStudio.Component.Windows11SDK.22000"
        }
        default {
            Write-Error "Unsupported VS Version: $Version"
            exit 1
        }
    }

    $installerPath = Join-Path $env:TEMP "vs_buildtools.exe"
    Write-Host "Downloading VS Bootstrapper for $Version from $vsBootstrapperUrl..."
    Invoke-WebRequest -Uri $vsBootstrapperUrl -OutFile $installerPath

    $arguments = @(
        "--quiet",
        "--wait",
        "--norestart",
        "--nocache",
        "--installPath",
        "C:\\VS\\$Version"
    )
    foreach ($component in $vsComponents) {
        $arguments += "--add"
        $arguments += $component
    }

    Write-Host "Starting VS Build Tools installer with arguments: $($arguments -join ' ')"
    $proc = Start-Process -FilePath $installerPath -ArgumentList $arguments -Wait -PassThru

    if ($proc.ExitCode -ne 0) {
        Write-Error "Visual Studio installation failed with exit code: $($proc.ExitCode)"
        # Attempt to read the log file for more details
        $logFile = Join-Path $env:TEMP "dd_bootstrapper_*.log"
        Get-ChildItem -Path $logFile | ForEach-Object {
            Write-Host "Displaying log file: $_.FullName"
            Get-Content $_.FullName | Out-String | Write-Warning
        }
        exit 1
    }

    Write-Host "--- Visual Studio Build Tools $Version installation completed successfully ---"
}

function Add-VSToPath {
    param(
        [string]$Version
    )
    
    Write-Host "--- Adding Visual Studio to PATH ---"
    $vsWherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vsWherePath)) {
        Write-Error "vswhere.exe not found. Cannot add VS to PATH."
        exit 1
    }

    $vsInstallPath = & $vsWherePath -latest -property installationPath -prerelease -format value
    if (-not $vsInstallPath) {
        Write-Error "Could not find Visual Studio installation path."
        exit 1
    }

    $vcToolsPath = Join-Path $vsInstallPath "VC\Tools\MSVC"
    if (-not (Test-Path $vcToolsPath)) {
        Write-Error "Could not find VC Tools path at $vcToolsPath"
        exit 1
    }

    # Find the latest MSVC toolset version
    $latestMsVcVersion = Get-ChildItem -Path $vcToolsPath | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latestMsVcVersion) {
        Write-Error "Could not find MSVC toolset version in $vcToolsPath"
        exit 1
    }

    $msvcBinPath = Join-Path $latestMsVcVersion.FullName "bin\Hostx64\x64"
    $commonIdePath = Join-Path $vsInstallPath "Common7\IDE"
    $msBuildPath = Join-Path $vsInstallPath "MSBuild\Current\Bin"

    Write-Host "Adding the following paths to GITHUB_PATH:"
    if (Test-Path $msvcBinPath) {
        Write-Host "- $msvcBinPath"
        Add-Content -Path $env:GITHUB_PATH -Value $msvcBinPath
    }
    if (Test-Path $commonIdePath) {
        Write-Host "- $commonIdePath"
        Add-Content -Path $env:GITHUB_PATH -Value $commonIdePath
    }
    if (Test-Path $msBuildPath) {
        Write-Host "- $msBuildPath"
        Add-Content -Path $env:GITHUB_PATH -Value $msBuildPath
    }

    Write-Host "Visual Studio environment has been configured."
}

# Main script execution
try {
    Uninstall-OldVS
    Install-VS -Version $VSVersion
    Add-VSToPath -Version $VSVersion
    Write-Host "Script finished successfully."
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}