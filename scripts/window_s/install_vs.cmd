@echo off
setlocal enabledelayedexpansion

:: usage: install_vs.cmd [2017|2019|2022]    (optional) set FORCE_UNINSTALL=1 to force uninstall existing
set "VS_VERSION=%~1"
if "%VS_VERSION%"=="" set "VS_VERSION=2022"
echo 选择的VS版本: %VS_VERSION%

:: 版本到 bootstrapper url 映射（企业版示例URL，视需可改 Community/BuildTools）
if "%VS_VERSION%"=="2017" (
    set "VS_URL=https://aka.ms/vs/15/release/vs_enterprise.exe"
) else if "%VS_VERSION%"=="2019" (
    set "VS_URL=https://aka.ms/vs/16/release/vs_enterprise.exe"
) else if "%VS_VERSION%"=="2022" (
    set "VS_URL=https://aka.ms/vs/17/release/vs_enterprise.exe"
) else (
    echo 不支持的VS版本: %VS_VERSION%
    echo 支持的版本: 2017, 2019, 2022
    exit /b 1
)

:: 组件列表（按需调整）
setlocal enabledelayedexpansion
set "COMP_LIST=Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.CMake.Project Microsoft.VisualStudio.Component.VC.ATL Microsoft.VisualStudio.Component.Windows10SDK.19041 Microsoft.VisualStudio.Component.TestTools.BuildTools Microsoft.VisualStudio.Component.VC.CoreIde"
endlocal & set "COMP_LIST=%COMP_LIST%"

:: Helper: 构建 --add 参数
set "ADD_ARGS="
for %%C in (%COMP_LIST%) do (
    set "ADD_ARGS=!ADD_ARGS! --add %%C"
)

:: 首先尝试使用 vswhere 查找已有安装（并检查是否满足要求）
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if exist "%VSWHERE%" (
    echo 找到 vswhere: %VSWHERE%
    for /f "usebackq tokens=*" %%V in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do (
        set "EXISTING_INSTALL=%%V"
    )
) else (
    echo 未找到 vswhere.exe，继续下一步（会尝试下载/安装）。
)

if defined EXISTING_INSTALL (
    echo 已检测到具有 VC.Tools 的安装: %EXISTING_INSTALL%
    echo 跳过安装步骤。
) else (
    if not "%FORCE_UNINSTALL%"=="1" (
        echo 没有检测到目标 installationPath，准备安装 Visual Studio %VS_VERSION%（如果 runner 已包含，建议跳过此脚本）。
    ) else (
        echo FORCE_UNINSTALL=1，准备卸载/重新安装（慎用）...
        :: 如果真的需要卸载，请用 vs_installer.exe 的 --uninstall 命令直接在独立命令行中运行（避免在 for /f 嵌套中调用）
    )

    :: 下载 bootstrapper
    echo 正在下载 VS bootstrapper...
    powershell -Command "try { Invoke-WebRequest -Uri '%VS_URL%' -OutFile 'vs_installer.exe' -UseBasicParsing; exit 0 } catch { exit 1 }"
    if not exist vs_installer.exe (
        echo 下载失败
        exit /b 1
    )

    :: 执行安装（将所有 --add 参数一次性传入）
    echo 正在执行: vs_installer.exe --quiet --wait --norestart --nocache %ADD_ARGS%
    :: 使用 start /wait 以确保不会被父进程重定向问题影响
    start /wait "" "%CD%\vs_installer.exe" --quiet --wait --norestart --nocache %ADD_ARGS%
    if errorlevel 1 (
        echo VS 安装失败，退出。
        exit /b 1
    )
)

:: 用 vswhere 再次查找安装路径并定位 vcvarsall.bat（更可靠）
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%V in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do (
        set "VS_INSTALL_PATH=%%V"
    )
)

if defined VS_INSTALL_PATH (
    set "VS_VCVARS=%VS_INSTALL_PATH%\VC\Auxiliary\Build\vcvarsall.bat"
    if exist "%VS_VCVARS%" (
        echo 找到 vcvarsall.bat: %VS_VCVARS%
    ) else (
        echo 未在 "%VS_INSTALL_PATH%" 下找到 vcvarsall.bat，尝试其他常见路径...
        :: 额外尝试 Program Files (x86) 和 Program Files
        for %%P in ("%ProgramFiles(x86)%\Microsoft Visual Studio\%VS_VERSION%\*" "%ProgramFiles%\Microsoft Visual Studio\%VS_VERSION%\*") do (
            for /f "delims=" %%F in ('dir /s /b "%%~P\VC\Auxiliary\Build\vcvarsall.bat" 2^>nul') do (
                set "VS_VCVARS=%%F"
                goto :vcvars_ok
            )
        )
        :vcvars_ok
    )
) else (
    echo vswhere 未找到安装路径，尝试全盘查找 vcvarsall.bat（会较慢）...
    for /f "delims=" %%F in ('dir /s /b "C:\Program Files (x86)\Microsoft Visual Studio\*\VC\Auxiliary\Build\vcvarsall.bat" 2^>nul') do (
        set "VS_VCVARS=%%F"
        goto :vcvars_ok2
    )
    for /f "delims=" %%F in ('dir /s /b "C:\Program Files\Microsoft Visual Studio\*\VC\Auxiliary\Build\vcvarsall.bat" 2^>nul') do (
        set "VS_VCVARS=%%F"
        goto :vcvars_ok2
    )
    :vcvars_ok2
)

if not defined VS_VCVARS (
    echo 未找到 vcvarsall.bat，退出。
    exit /b 1
)

echo VCVARS 路径: %VS_VCVARS%

:: 将路径写入 GitHub Actions 环境文件（persist）
echo VS_VCVARS=%VS_VCVARS%>>"%GITHUB_ENV%"
echo VS_VERSION=%VS_VERSION%>>"%GITHUB_ENV%"

:: 将 bin 路径添加到 PATH（寻找最新 MSVC 工具链）
for /f "delims=" %%D in ('dir /b "%~dp0" 2^>nul') do rem >nul
:: 计算 VS 安装根目录
for %%I in ("%VS_VCVARS%\..\..\..") do set "VS_INSTALL_ROOT=%%~fi"
set "VC_TOOLS_PATH=%VS_INSTALL_ROOT%\VC\Tools\MSVC"
set "LATEST_VERSION="
for /f "tokens=*" %%V in ('dir /b "%VC_TOOLS_PATH%" 2^>nul ^| sort /r') do (
    set "LATEST_VERSION=%%V"
    goto :verfound
)
:verfound
if defined LATEST_VERSION (
    set "BIN_PATH=%VC_TOOLS_PATH%\%LATEST_VERSION%\bin\Hostx64\x64"
    if exist "%BIN_PATH%" (
        echo PATH=%BIN_PATH%;%PATH%>>"%GITHUB_ENV%"
        echo 已把 %BIN_PATH% 添加到 PATH（通过 GITHUB_ENV）
    ) else (
        echo 未找到预期的编译器 bin 路径: %BIN_PATH%
    )
) else (
    echo 未找到 VC Tools 版本目录: %VC_TOOLS_PATH%
)

echo 安装/配置完成
endlocal
exit /b 0
