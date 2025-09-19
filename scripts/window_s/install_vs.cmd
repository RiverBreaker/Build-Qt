@echo off
setlocal enabledelayedexpansion

REM Batch script to install Visual Studio for GitHub Actions

REM Set VS Version from argument, default to 2022
set "VS_VERSION=%1"
if not defined VS_VERSION set "VS_VERSION=2022"

echo --- Selected VS Version: %VS_VERSION% ---

REM Uninstall existing VS instances
echo --- Searching for existing Visual Studio installations to uninstall ---
if exist "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" (
    for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -all -property installationPath`) do (
        echo Uninstalling Visual Studio from: %%i
        start "" /wait "%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vs_installer.exe" uninstall --path "%%i" --quiet --force --norestart
        if !errorlevel! neq 0 (
            echo WARNING: Failed to uninstall Visual Studio at %%i. Exit code: !errorlevel!
        )
    )
) else (
    echo vswhere.exe not found. Skipping uninstallation.
)
echo --- Finished uninstalling old Visual Studio versions ---


REM Define download URLs and components for different VS versions
set "VS_URL_2017=https://aka.ms/vs/15/release/vs_buildtools.exe"
set "VS_COMPONENTS_2017=--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.17763"

set "VS_URL_2019=https://aka.ms/vs/16/release/vs_buildtools.exe"
set "VS_COMPONENTS_2019=--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041"

set "VS_URL_2022=https://aka.ms/vs/17/release/vs_buildtools.exe"
set "VS_COMPONENTS_2022=--add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22000"

REM Select URL and components based on version
set "VS_URL=!VS_URL_%VS_VERSION%!"
set "VS_COMPONENTS=!VS_COMPONENTS_%VS_VERSION%!"

if not defined VS_URL (
    echo ERROR: Unsupported VS Version: %VS_VERSION%
    exit /b 1
)

REM Download and install VS Build Tools
set "INSTALLER_PATH=%TEMP%\vs_buildtools.exe"
echo --- Downloading VS Bootstrapper for %VS_VERSION% from %VS_URL% ---
curl -L -o "%INSTALLER_PATH%" "%VS_URL%"

echo --- Starting VS Build Tools installer... ---
start "" /wait "%INSTALLER_PATH%" --quiet --wait --norestart --nocache --installPath "C:\VS\%VS_VERSION%" !VS_COMPONENTS!

if !errorlevel! neq 0 (
    echo ERROR: Visual Studio installation failed with exit code: !errorlevel!
    REM Try to find and display logs
    for /r "%TEMP%" %%f in (dd_bootstrapper_*.log) do (
        echo Displaying log file: %%f
        type "%%f"
    )
    exit /b 1
)

echo --- Visual Studio Build Tools %VS_VERSION% installation completed successfully. ---


REM Add VS to PATH
echo --- Adding Visual Studio to PATH ---
set "VSWHERE_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%VSWHERE_PATH%" (
    echo ERROR: vswhere.exe not found. Cannot add VS to PATH.
    exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE_PATH%" -latest -property installationPath -prerelease -format value`) do (
    set "VS_INSTALL_PATH=%%i"
)

if not defined VS_INSTALL_PATH (
    echo ERROR: Could not find Visual Studio installation path.
    exit /b 1
)

set "VC_TOOLS_PATH=!VS_INSTALL_PATH!\VC\Tools\MSVC"
if not exist "!VC_TOOLS_PATH!" (
    echo ERROR: Could not find VC Tools path at !VC_TOOLS_PATH!
    exit /b 1
)

REM Find the latest MSVC toolset version (get the last directory name in reverse sorted list)
set "LATEST_MSVC_VERSION="
for /f "tokens=*" %%d in ('dir /b /ad /o-n "!VC_TOOLS_PATH!"') do (
    set "LATEST_MSVC_VERSION=%%d"
    goto :found_msvc_cmd
)
:found_msvc_cmd

if not defined LATEST_MSVC_VERSION (
    echo ERROR: Could not find MSVC toolset version in !VC_TOOLS_PATH!
    exit /b 1
)

set "MSVC_BIN_PATH=!VC_TOOLS_PATH!\!LATEST_MSVC_VERSION!\bin\Hostx64\x64"
set "COMMON_IDE_PATH=!VS_INSTALL_PATH!\Common7\IDE"
set "MSBUILD_PATH=!VS_INSTALL_PATH!\MSBuild\Current\Bin"

if exist "!MSVC_BIN_PATH!" (
    echo Adding to GITHUB_PATH: !MSVC_BIN_PATH!
    echo !MSVC_BIN_PATH!>>"%GITHUB_PATH%"
)
if exist "!COMMON_IDE_PATH!" (
    echo Adding to GITHUB_PATH: !COMMON_IDE_PATH!
    echo !COMMON_IDE_PATH!>>"%GITHUB_PATH%"
)
if exist "!MSBUILD_PATH!" (
    echo Adding to GITHUB_PATH: !MSBUILD_PATH!
    echo !MSBUILD_PATH!>>"%GITHUB_PATH%"
)

echo Visual Studio environment has been configured.

endlocal
