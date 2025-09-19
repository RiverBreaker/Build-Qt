@echo off
setlocal enabledelayedexpansion

:: 参数处理
set VS_VERSION=%~1
if "%VS_VERSION%"=="" set VS_VERSION=2022

echo 选择的VS版本: %VS_VERSION%

:: 卸载所有已安装的VS版本
echo 正在卸载已安装的Visual Studio版本...
for /f "tokens=*" %%i in ('where /r "C:\Program Files (x86)\Microsoft Visual Studio" vs_installer.exe 2^>nul') do (
    echo 找到安装程序: %%i
    echo 正在卸载...
    %%i uninstall --quiet --wait --norestart --force
    timeout /t 5 /nobreak >nul
)

:: 根据版本设置下载URL
if "%VS_VERSION%"=="2017" (
    set VS_URL=https://aka.ms/vs/15/release/vs_enterprise.exe
    set VS_YEAR=2017
) else if "%VS_VERSION%"=="2019" (
    set VS_URL=https://aka.ms/vs/16/release/vs_enterprise.exe
    set VS_YEAR=2019
) else if "%VS_VERSION%"=="2022" (
    set VS_URL=https://aka.ms/vs/17/release/vs_enterprise.exe
    set VS_YEAR=2022
) else (
    echo 不支持的VS版本: %VS_VERSION%
    echo 支持的版本: 2017, 2019, 2022
    exit 1
)

echo 正在下载VS%VS_VERSION%安装程序...
curl -L -o vs_installer.exe "%VS_URL%"

if not exist vs_installer.exe (
    echo 下载失败
    exit 1
)

:: 根据版本设置不同的组件
if "%VS_VERSION%"=="2017" (
    set COMPONENTS=^
Microsoft.VisualStudio.Workload.NativeDesktop;^
Microsoft.VisualStudio.Component.VC.Tools.x86.x64;^
Microsoft.VisualStudio.Component.VC.CMake.Project;^
Microsoft.VisualStudio.Component.VC.ATL;^
Microsoft.VisualStudio.Component.Windows10SDK.17763;^
Microsoft.VisualStudio.Component.TestTools.BuildTools;^
Microsoft.VisualStudio.Component.VC.CoreIde
) else if "%VS_VERSION%"=="2019" (
    set COMPONENTS=^
Microsoft.VisualStudio.Workload.NativeDesktop;^
Microsoft.VisualStudio.Component.VC.Tools.x86.x64;^
Microsoft.VisualStudio.Component.VC.CMake.Project;^
Microsoft.VisualStudio.Component.VC.ATL;^
Microsoft.VisualStudio.Component.Windows10SDK.19041;^
Microsoft.VisualStudio.Component.TestTools.BuildTools;^
Microsoft.VisualStudio.Component.VC.CoreIde
) else if "%VS_VERSION%"=="2022" (
    set COMPONENTS=^
Microsoft.VisualStudio.Workload.NativeDesktop;^
Microsoft.VisualStudio.Component.VC.Tools.x86.x64;^
Microsoft.VisualStudio.Component.VC.CMake.Project;^
Microsoft.VisualStudio.Component.VC.ATL;^
Microsoft.VisualStudio.Component.Windows10SDK.20348;^
Microsoft.VisualStudio.Component.TestTools.BuildTools;^
Microsoft.VisualStudio.Component.VC.CoreIde
)

echo 正在安装VS%VS_VERSION%必要组件...
vs_installer.exe --quiet --wait --norestart --nocache ^
    --add !COMPONENTS:;= --add !

if errorlevel 1 (
    echo VS%VS_VERSION%安装失败
    exit 1
)

:: 查找vcvarsall.bat
echo 正在查找VC工具...
set VCVARS_FOUND=0
for /f "tokens=*" %%i in ('dir /s /b "C:\Program Files (x86)\Microsoft Visual Studio\%VS_YEAR%\*\VC\Auxiliary\Build\vcvarsall.bat" 2^>nul') do (
    set "VS_VCVARS=%%i"
    set VCVARS_FOUND=1
    goto :vcvars_found
)

:vcvars_found
if !VCVARS_FOUND! equ 0 (
    echo 未找到vcvarsall.bat，尝试其他路径...
    for /f "tokens=*" %%i in ('dir /s /b "C:\Program Files\Microsoft Visual Studio\%VS_YEAR%\*\VC\Auxiliary\Build\vcvarsall.bat" 2^>nul') do (
        set "VS_VCVARS=%%i"
        set VCVARS_FOUND=1
    )
)

if !VCVARS_FOUND! equ 0 (
    echo 未找到vcvarsall.bat文件
    exit 1
)

echo VCVARS路径: !VS_VCVARS!

:: 设置环境变量
echo "VS_VCVARS=!VS_VCVARS!" >> "%GITHUB_ENV%"
echo "VS_VERSION=%VS_VERSION%" >> "%GITHUB_ENV%"

:: 添加到PATH
for %%i in ("!VS_VCVARS!\..\..\..\..") do set "VS_INSTALL_PATH=%%~fi"
set "VC_TOOLS_PATH=!VS_INSTALL_PATH!\VC\Tools\MSVC"

:: 查找最新版本的编译器工具
set LATEST_VERSION=
for /f "tokens=*" %%d in ('dir /b "!VC_TOOLS_PATH!" 2^>nul ^| sort /r') do (
    set "LATEST_VERSION=%%d"
    goto :version_found
)

:version_found
if not defined LATEST_VERSION (
    echo 未找到编译器工具
    exit 1
)

set "BIN_PATH=!VC_TOOLS_PATH!\!LATEST_VERSION!\bin\Hostx64\x64"
if exist "!BIN_PATH!" (
    echo "PATH=!BIN_PATH!;%PATH%" >> "%GITHUB_ENV%"
    echo 已添加到PATH: !BIN_PATH!
) else (
    echo 编译器路径不存在: !BIN_PATH!
)

:: 添加通用工具到PATH
set "COMMON_TOOLS=!VS_INSTALL_PATH!\Common7\Tools"
if exist "!COMMON_TOOLS!" (
    echo "PATH=!COMMON_TOOLS!;%PATH%" >> "%GITHUB_ENV%"
)

set "COMMON_IDE=!VS_INSTALL_PATH!\Common7\IDE"
if exist "!COMMON_IDE!" (
    echo "PATH=!COMMON_IDE!;%PATH%" >> "%GITHUB_ENV%"
)

echo VS%VS_VERSION%安装和配置完成

endlocal