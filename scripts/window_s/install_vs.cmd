@echo off
setlocal enabledelayedexpansion

REM Batch script to install Visual Studio for GitHub Actions

REM Set VS Version from argument, default to 2022
set "VS_VERSION=%1"
if not defined VS_VERSION set "VS_VERSION=2022"

echo --- Selected VS Version: %VS_VERSION% ---

REM Uninstall existing VS instances
echo --- Searching for and running InstallCleanup.exe ---
set "INSTALL_CLEANUP_PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\InstallCleanup.exe"

if exist "%INSTALL_CLEANUP_PATH%" (
    echo Found InstallCleanup.exe. Running cleanup...
    "%INSTALL_CLEANUP_PATH%" -f
    set "CLEANUP_EXIT_CODE=!errorlevel!"
    if !CLEANUP_EXIT_CODE! neq 0 (
        echo WARNING: InstallCleanup.exe finished with exit code: !CLEANUP_EXIT_CODE!
    ) else (
        echo InstallCleanup.exe completed successfully.
    )
) else (
    echo InstallCleanup.exe not found at "%INSTALL_CLEANUP_PATH%". Skipping cleanup.
)
echo --- Finished cleaning up old Visual Studio versions ---

echo --- Attempting to repair system components and .NET Framework ---
DISM.exe /Online /Cleanup-Image /RestoreHealth
set "DISM_EXIT_CODE=!errorlevel!"
if !DISM_EXIT_CODE! neq 0 (
    echo WARNING: DISM.exe finished with exit code: !DISM_EXIT_CODE!. The installation may fail.
) else (
    echo System component repair completed successfully.
)


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

rem Download the bootstrapper
echo --- Downloading VS Bootstrapper for %VS_VERSION% from `%VS_URL%` ---
curl -L -o vs_buildtools.exe "%VS_URL%"
if !errorlevel! neq 0 (
    echo Failed to download Visual Studio bootstrapper.
    exit /b 1
)

rem Run the installer
echo --- Starting VS Build Tools installer... ---
start "" /wait vs_buildtools.exe %VS_COMPONENTS% --quiet --wait --norestart --nocache
set INSTALL_EXIT_CODE=!errorlevel!

del vs_buildtools.exe

if %INSTALL_EXIT_CODE% equ 0 (
    echo --- Visual Studio Build Tools %VS_VERSION% installation completed successfully. ---
) else (
    echo --- Visual Studio Build Tools %VS_VERSION% installation failed with exit code %INSTALL_EXIT_CODE%. ---
    if exist "%ProgramFiles(x86)%\Microsoft\Temp\dd_bootstrapper_*.log" (
        echo --- Displaying bootstrapper log ---
        type "%ProgramFiles(x86)%\Microsoft\Temp\dd_bootstrapper_*.log"
    )
    exit /b 1
)

echo --- Adding Visual Studio to PATH ---
set "VS_INSTALL_PATH="
for /f "usebackq tokens=*" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -version %VS_VERSION% -property installationPath -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64`) do (
    set "VS_INSTALL_PATH=%%i"
)

if not defined VS_INSTALL_PATH (
    echo Failed to find Visual Studio %VS_VERSION% installation path.
    exit /b 1
)

set "MSVC_DIR="
for /f "delims=" %%d in ('dir /b /ad /o-n "%VS_INSTALL_PATH%\VC\Tools\MSVC"') do (
    set "MSVC_DIR=%%d"
    goto :found_msvc_dir_for_path
)
:found_msvc_dir_for_path

if defined MSVC_DIR (
    set "MSVC_BIN_PATH=%VS_INSTALL_PATH%\VC\Tools\MSVC\%MSVC_DIR%\bin\Hostx64\x64"
    echo Adding to GITHUB_PATH: %MSVC_BIN_PATH%
    echo %MSVC_BIN_PATH%>>"%GITHUB_PATH%"
) else (
    echo MSVC tools directory not found for PATH setup.
)

set "COMMON_IDE_PATH=%VS_INSTALL_PATH%\Common7\IDE"
echo Adding to GITHUB_PATH: %COMMON_IDE_PATH%
echo %COMMON_IDE_PATH%>>"%GITHUB_PATH%"

set "MSBUILD_PATH=%VS_INSTALL_PATH%\MSBuild\Current\Bin"
echo Adding to GITHUB_PATH: %MSBUILD_PATH%
echo %MSBUILD_PATH%>>"%GITHUB_PATH%"

echo --- Verifying installation ---
if defined VS_INSTALL_PATH (
    echo Visual Studio %VS_VERSION% found at: %VS_INSTALL_PATH%

    if defined MSVC_DIR (
        set "CL_PATH=%VS_INSTALL_PATH%\VC\Tools\MSVC\%MSVC_DIR%\bin\Hostx64\x64\cl.exe"
        if exist "%CL_PATH%" (
            echo Verifying compiler version:
            "%CL_PATH%" /version
        ) else (
            echo cl.exe not found at %CL_PATH%
        )
    ) else (
        echo MSVC tools directory not found for verification.
    )

    if exist "%MSBUILD_PATH%" (
        echo Verifying MSBuild version:
        "%MSBUILD_PATH%" -version
    ) else (
        echo MSBuild.exe not found.
    )
) else (
    echo Visual Studio %VS_VERSION% installation not found after install.
)

echo Visual Studio environment has been configured.

endlocal
