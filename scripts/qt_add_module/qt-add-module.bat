@echo off
setlocal enabledelayedexpansion

:: 默认值
set "QT_VERSION="
set "D_FAKE_DIR="
set "QT_REAL_SOURCE_DIR="
set "QT_MODULE_NAME="
set "QT_INSTALLED_DIR="
set "QT_MODULE_INSTALL_DIR="

:: 标记我们是否创建了 D: 映射（最后才删除）
set "CREATED_SUBST=0"

:: 解析参数
:parse_loop
if "%~1"=="" goto :validate_args

set "current_arg=%~1"

:: 处理不同的参数格式
if "!current_arg!"=="--qt-version" (
    if "%~2"=="" (
        echo Error: --qt-version requires a value
        exit /b 1
    )
    set "QT_VERSION=%~2"
    shift
    shift
    goto :parse_loop
)

if "!current_arg!"=="--d-fake-dir" (
    if "%~2"=="" (
        echo Error: --d-fake-dir requires a value
        exit /b 1
    )
    set "D_FAKE_DIR=%~2"
    shift
    shift
    goto :parse_loop
)

if "!current_arg!"=="--qt-source-dir" (
    if "%~2"=="" (
        echo Error: --qt-source-dir requires a value
        exit /b 1
    )
    set "QT_REAL_SOURCE_DIR=%~2"
    shift
    shift
    goto :parse_loop
)

if "!current_arg!"=="--add-module" (
    if "%~2"=="" (
        echo Error: --add-module requires a value
        exit /b 1
    )
    set "QT_MODULE_NAME=%~2"
    shift
    shift
    goto :parse_loop
)

if "!current_arg!"=="--qt-installed-dir" (
    if "%~2"=="" (
        echo Error: --qt-installed-dir requires a value
        exit /b 1
    )
    set "QT_INSTALLED_DIR=%~2"
    shift
    shift
    goto :parse_loop
)

if "!current_arg!"=="--install-dir" (
    if "%~2"=="" (
        echo Error: --install-dir requires a value
        exit /b 1
    )
    set "QT_MODULE_INSTALL_DIR=%~2"
    shift
    shift
    goto :parse_loop
)

:: 也支持 key=value 格式
if "!current_arg:~0,14!"=="--qt-version=" (
    set "QT_VERSION=!current_arg:~14!"
    shift
    goto :parse_loop
)

if "!current_arg:~0,14!"=="--d-fake-dir=" (
    set "D_FAKE_DIR=!current_arg:~14!"
    shift
    goto :parse_loop
)

if "!current_arg:~0,17!"=="--qt-source-dir=" (
    set "QT_REAL_SOURCE_DIR=!current_arg:~17!"
    shift
    goto :parse_loop
)

if "!current_arg:~0,13!"=="--add-module=" (
    set "QT_MODULE_NAME=!current_arg:~13!"
    shift
    goto :parse_loop
)

if "!current_arg:~0,19!"=="--qt-installed-dir=" (
    set "QT_INSTALLED_DIR=!current_arg:~19!"
    shift
    goto :parse_loop
)

if "!current_arg:~0,14!"=="--install-dir=" (
    set "QT_MODULE_INSTALL_DIR=!current_arg:~14!"
    shift
    goto :parse_loop
)

echo Unknown parameter: %~1
exit /b 1

:: === 参数校验 ===
:validate_args
if not defined QT_VERSION (
    echo Error: --qt-version is required.
    exit /b 1
)

if not defined D_FAKE_DIR (
    echo Error: --d-fake-dir is required.
    exit /b 1
)
if not defined QT_REAL_SOURCE_DIR (
    echo Error: --qt-source-dir is required.
    exit /b 1
)
if not defined QT_MODULE_NAME (
    echo Error: --add-module is required.
    exit /b 1
)
if not defined QT_INSTALLED_DIR (
    echo Error: --qt-installed-dir is required.
    exit /b 1
)
if not defined QT_MODULE_INSTALL_DIR (
    set "QT_MODULE_INSTALL_DIR=%QT_INSTALLED_DIR%"
)

echo Parsed parameters:
echo QT_VERSION=%QT_VERSION%
echo D_FAKE_DIR=%D_FAKE_DIR%
echo QT_REAL_SOURCE_DIR=%QT_REAL_SOURCE_DIR%
echo QT_MODULE_NAME=%QT_MODULE_NAME%
echo QT_INSTALLED_DIR=%QT_INSTALLED_DIR%
echo QT_MODULE_INSTALL_DIR=%QT_MODULE_INSTALL_DIR%

:: 构建路径（把构建放到独立目录，避免污染当前目录）
set "QT_ORIGIN_SOURCE_ROOT=D:\a\_temp\qt6_src"
set "QT_ORIGIN_SOURCE_DIR=%QT_ORIGIN_SOURCE_ROOT%\qt-everywhere-src-%QT_VERSION%"
set "QT_MODULE_ORIGIN_SOURCE_DIR=%QT_REAL_SOURCE_DIR%\%QT_MODULE_NAME%"
set "QT_MODULE_SOURCE_DIR=D:\qms"

:: 检查或创建 D: 盘（只在不存在时创建并设置标记）
if exist D:\nul (
    echo D: drive already exists.
) else (
    echo D: drive not found. Creating via subst...
    subst D: "%D_FAKE_DIR%"
    if not exist D:\nul (
        echo Failed to create D: drive via subst.
        exit /b 1
    )
    echo Subst D: drive success.
    set "CREATED_SUBST=1"
)

:: 创建源码目录链接（如果需要）
if not exist "%QT_ORIGIN_SOURCE_ROOT%" (
    mkdir "%QT_ORIGIN_SOURCE_ROOT%" 2>nul || (echo Failed to create "%QT_ORIGIN_SOURCE_ROOT%" & exit /b 1)
)

:: 如果已有目标链接或目录，尝试移除（谨慎处理）
if exist "%QT_ORIGIN_SOURCE_DIR%" (
    rmdir "%QT_ORIGIN_SOURCE_DIR%" 2>nul || (
        echo Warning: Could not remove "%QT_ORIGIN_SOURCE_DIR%". It may be non-empty or not a junction.
        echo Please remove it manually if it is a stale link.
    )
)

:: 创建Qt源码根目录的链接（D:\qt\src -> 实际Qt源码根目录）
if not exist "%QT_ORIGIN_SOURCE_DIR%\" (
    mklink /J "%QT_ORIGIN_SOURCE_DIR%" "%QT_REAL_SOURCE_DIR%" 2>nul
    if errorlevel 1 (
        echo Failed to create junction "%QT_ORIGIN_SOURCE_DIR%" -> "%QT_REAL_SOURCE_DIR%".
        echo Note: mklink may require Administrator privileges on some systems.
        exit /b 1
    )
    echo Created Qt source junction: "%QT_ORIGIN_SOURCE_DIR%" -> "%QT_REAL_SOURCE_DIR%"
) else (
    echo "%QT_ORIGIN_SOURCE_DIR%" already exists, skipping link creation.
)

:: 移动/链接模块目录（若已有旧链接先尝试删除）
if exist "%QT_MODULE_SOURCE_DIR%" (
    rmdir "%QT_MODULE_SOURCE_DIR%" 2>nul || (
        echo Warning: Could not remove existing "%QT_MODULE_SOURCE_DIR%". It may be non-empty or not a junction.
    )
)

:: 检查模块源码是否存在（通过新的链接路径访问）
set "QT_MODULE_VIA_LINK_DIR=%QT_ORIGIN_SOURCE_DIR%\%QT_MODULE_NAME%"
if not exist "%QT_MODULE_VIA_LINK_DIR%" (
    echo Error: Module source not found at "%QT_MODULE_VIA_LINK_DIR%"
    if "!CREATED_SUBST!"=="1" (
        echo Undoing created D: mapping...
        subst D: /D >nul 2>&1
    )
    exit /b 1
)

:: 创建模块链接（D:\qtwebengine -> D:\qt\src\qtwebengine，避免跨驱动器路径问题）
mklink /J "%QT_MODULE_SOURCE_DIR%" "%QT_MODULE_VIA_LINK_DIR%" 2>nul
if errorlevel 1 (
    echo Failed to create junction "%QT_MODULE_SOURCE_DIR%" -> "%QT_MODULE_VIA_LINK_DIR%".
    echo Note: mklink may require Administrator privileges on some systems.
    if "!CREATED_SUBST!"=="1" (
        subst D: /D >nul 2>&1
    )
    exit /b 1
)

echo Created module junction: "%QT_MODULE_SOURCE_DIR%" -> "%QT_MODULE_VIA_LINK_DIR%"

:: 构建目录（放到 D: 盘上，确保与源码在同一盘符）
set "BUILD_DIR=D:\build\%QT_MODULE_NAME%"
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%" 2>nul || (echo Failed to create build dir "%BUILD_DIR%" & exit /b 1)
cd /d "%BUILD_DIR%"

::设置控制台代码页为UTF-8
chcp 65001 >nul

:: 设置日志文件路径
set "LOG_FILE=%~dp0logs\%QT_MODULE_NAME%_build_%date:~0,4%%date:~5,2%%date:~8,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log"
set "LOG_FILE=%LOG_FILE: =0%"
if not exist "%~dp0logs" mkdir "%~dp0logs" 2>nul

:: 创建UTF-8 BOM头的日志文件
echo.>"%LOG_FILE%"
powershell -Command "[System.IO.File]::WriteAllText('%LOG_FILE%', '', [System.Text.Encoding]::UTF8)"

set "PYTHON_PATH=E:\dev\anaconda3\python.exe"

echo.
echo Configuring module '%QT_MODULE_NAME%'...
:: 使用PowerShell以UTF-8编码写入日志
powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Starting configuration for module ''%QT_MODULE_NAME%''' -Encoding UTF8"

:: 创建临时批处理文件用于UTF-8输出重定向
set "TEMP_BAT=%TEMP%\qt_config_%RANDOM%.bat"
echo @echo off > "%TEMP_BAT%"
echo chcp 65001 ^>nul >> "%TEMP_BAT%"
echo call "%QT_INSTALLED_DIR%\bin\qt-configure-module.bat" "%QT_MODULE_SOURCE_DIR%" -- -DPython3_EXECUTABLE="%PYTHON_PATH%" -Wno-dev >> "%TEMP_BAT%"

call "%TEMP_BAT%" >> "%LOG_FILE%" 2>&1
set "CONFIG_RESULT=%errorlevel%"
del "%TEMP_BAT%" 2>nul

if %CONFIG_RESULT% neq 0 (
    echo qt-configure-module failed. Check log: %LOG_FILE%
    powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] qt-configure-module failed with error level %CONFIG_RESULT%' -Encoding UTF8"
    if "!CREATED_SUBST!"=="1" subst D: /D >nul 2>&1
    exit /b 1
)

echo Building module '%QT_MODULE_NAME%'...
powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Starting build for module ''%QT_MODULE_NAME%''' -Encoding UTF8"

:: 创建临时批处理文件用于UTF-8构建输出
set "TEMP_BAT=%TEMP%\qt_build_%RANDOM%.bat"
echo @echo off > "%TEMP_BAT%"
echo chcp 65001 ^>nul >> "%TEMP_BAT%"
echo cmake --build . --parallel >> "%TEMP_BAT%"

call "%TEMP_BAT%" >> "%LOG_FILE%" 2>&1
set "BUILD_RESULT=%errorlevel%"
del "%TEMP_BAT%" 2>nul

if %BUILD_RESULT% neq 0 (
    echo Build failed. Check log: %LOG_FILE%
    powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Build failed with error level %BUILD_RESULT%' -Encoding UTF8"
    if "!CREATED_SUBST!"=="1" subst D: /D >nul 2>&1
    exit /b 1
)

echo Installing module '%QT_MODULE_NAME%'...
powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Starting installation for module ''%QT_MODULE_NAME%''' -Encoding UTF8"

:: 创建临时批处理文件用于UTF-8安装输出
set "TEMP_BAT=%TEMP%\qt_install_%RANDOM%.bat"
echo @echo off > "%TEMP_BAT%"
echo chcp 65001 ^>nul >> "%TEMP_BAT%"
echo cmake --install . --prefix "%QT_MODULE_INSTALL_DIR%" >> "%TEMP_BAT%"

call "%TEMP_BAT%" >> "%LOG_FILE%" 2>&1
set "INSTALL_RESULT=%errorlevel%"
del "%TEMP_BAT%" 2>nul

if %INSTALL_RESULT% neq 0 (
    echo Install failed. Check log: %LOG_FILE%
    powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Install failed with error level %INSTALL_RESULT%' -Encoding UTF8"
    if "!CREATED_SUBST!"=="1" subst D: /D >nul 2>&1
    exit /b 1
)

echo.
echo Module '%QT_MODULE_NAME%' successfully built and installed.
powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Module ''%QT_MODULE_NAME%'' successfully built and installed' -Encoding UTF8"
echo Build log saved to: %LOG_FILE%

:: 仅在我们自己创建了 D: 映射时才删除
if "!CREATED_SUBST!"=="1" (
    echo Deleting temporary D: mapping...
    powershell -Command "Add-Content -Path '%LOG_FILE%' -Value '[%date% %time%] Deleting temporary D: mapping' -Encoding UTF8"
    subst D: /D >nul 2>&1
)

endlocal
exit /b 0
