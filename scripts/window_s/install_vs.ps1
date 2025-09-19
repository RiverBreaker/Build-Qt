param(
    [ValidateSet("2017", "2019", "2022")]
    [string]$VSVersion = "2022"
)

function Get-VSComponents {
    param([string]$Version)

    $components = @()

    # 公共组件
    $components += "Microsoft.VisualStudio.Workload.NativeDesktop"
    $components += "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
    $components += "Microsoft.VisualStudio.Component.VC.CMake.Project"
    $components += "Microsoft.VisualStudio.Component.VC.ATL"
    $components += "Microsoft.VisualStudio.Component.TestTools.BuildTools"
    $components += "Microsoft.VisualStudio.Component.VC.CoreIde"

    # 版本特定的Windows SDK
    switch ($Version) {
        "2017" { $components += "Microsoft.VisualStudio.Component.Windows10SDK.17763" }
        "2019" { $components += "Microsoft.VisualStudio.Component.Windows10SDK.19041" }
        "2022" { $components += "Microsoft.VisualStudio.Component.Windows10SDK.20348" }
    }

    return $components
}

Write-Host "选择的VS版本: $VSVersion"

# 卸载所有已安装的VS版本
Write-Host "正在卸载已安装的Visual Studio版本..."
$installers = @()
$installers += Get-ChildItem -Path "C:\Program Files (x86)\Microsoft Visual Studio" -Recurse -Filter "vs_installer.exe" -ErrorAction SilentlyContinue
$installers += Get-ChildItem -Path "C:\Program Files\Microsoft Visual Studio" -Recurse -Filter "vs_installer.exe" -ErrorAction SilentlyContinue

foreach ($installer in $installers) {
    Write-Host "找到安装程序: $($installer.FullName)"
    try {
        $process = Start-Process -FilePath $installer.FullName -ArgumentList @("uninstall", "--quiet", "--wait", "--norestart", "--force") -Wait -PassThru -NoNewWindow
        Write-Host "卸载完成，退出代码: $($process.ExitCode)"
        Start-Sleep -Seconds 3
    }
    catch {
        Write-Warning "卸载失败: $($_.Exception.Message)"
    }
}

# 根据版本设置下载URL
$vsUrls = @{
    "2017" = "https://aka.ms/vs/15/release/vs_enterprise.exe"
    "2019" = "https://aka.ms/vs/16/release/vs_enterprise.exe"
    "2022" = "https://aka.ms/vs/17/release/vs_enterprise.exe"
}

if (-not $vsUrls.ContainsKey($VSVersion)) {
    Write-Error "不支持的VS版本: $VSVersion。支持的版本: $($vsUrls.Keys -join ', ')"
    exit 1
}

$vsUrl = $vsUrls[$VSVersion]

# 下载VS安装程序
Write-Host "正在下载VS$VSVersion安装程序..."
$vsInstallerPath = "$env:TEMP\vs_installer_$VSVersion.exe"

try {
    $progressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $vsUrl -OutFile $vsInstallerPath
    Write-Host "下载完成"
}
catch {
    Write-Error "下载失败: $($_.Exception.Message)"
    exit 1
}
finally {
    $progressPreference = 'Continue'
}

# 获取版本特定的组件
$components = Get-VSComponents -Version $VSVersion
Write-Host "安装组件: $($components -join ', ')"

# 安装VS必要组件
Write-Host "正在安装VS$VSVersion必要组件..."
$installArgs = @("--quiet", "--wait", "--norestart", "--nocache")
foreach ($component in $components) {
    $installArgs += "--add"
    $installArgs += $component
}

try {
    $process = Start-Process -FilePath $vsInstallerPath -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Error "VS$VSVersion安装失败，退出代码: $($process.ExitCode)"
        exit 1
    }
}
catch {
    Write-Error "安装过程出错: $($_.Exception.Message)"
    exit 1
}

# 查找vcvarsall.bat
Write-Host "正在查找VC工具..."
$searchPaths = @(
    "C:\Program Files (x86)\Microsoft Visual Studio\$VSVersion\*",
    "C:\Program Files\Microsoft Visual Studio\$VSVersion\*"
)

$vcvarsPath = $null
foreach ($path in $searchPaths) {
    $vcvarsPath = Get-ChildItem -Path $path -Recurse -Filter "vcvarsall.bat" -ErrorAction SilentlyContinue |
                  Select-Object -First 1 -ExpandProperty FullName
    if ($vcvarsPath) { break }
}

if (-not $vcvarsPath) {
    Write-Error "未找到vcvarsall.bat文件"
    exit 1
}

Write-Host "VCVARS路径: $vcvarsPath"

# 设置环境变量
$env:VS_VCVARS = $vcvarsPath
$env:VS_VERSION = $VSVersion
"VS_VCVARS=$vcvarsPath" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
"VS_VERSION=$VSVersion" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8

# 添加到PATH
$vsInstallPath = Split-Path (Split-Path (Split-Path $vcvarsPath))
$vcToolsPath = Join-Path $vsInstallPath "VC\Tools\MSVC"

# 查找最新版本的编译器
$latestVersion = Get-ChildItem -Path $vcToolsPath -ErrorAction SilentlyContinue |
                 Where-Object { $_.PSIsContainer } |
                 Sort-Object Name -Descending |
                 Select-Object -First 1

if ($latestVersion) {
    $binPaths = @(
        Join-Path $latestVersion.FullName "bin\Hostx64\x64",
        Join-Path $latestVersion.FullName "bin\Hostx86\x86"
    )

    foreach ($binPath in $binPaths) {
        if (Test-Path $binPath) {
            $env:PATH = "$binPath;$env:PATH"
            "PATH=$binPath;$env:PATH" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
            Write-Host "已添加编译器工具到PATH: $binPath"
        }
    }
}

# 添加通用工具到PATH
$commonPaths = @(
    Join-Path $vsInstallPath "Common7\Tools",
    Join-Path $vsInstallPath "Common7\IDE",
    Join-Path $vsInstallPath "MSBuild\Current\Bin"
)

foreach ($commonPath in $commonPaths) {
    if (Test-Path $commonPath) {
        $env:PATH = "$commonPath;$env:PATH"
        "PATH=$commonPath;$env:PATH" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
        Write-Host "已添加通用工具到PATH: $commonPath"
    }
}

Write-Host "VS$VSVersion安装和配置完成"

# 验证安装
Write-Host "`n验证安装:"
try {
    $clVersion = & "cl.exe" 2>&1 | Select-String "Version" | Select-Object -First 1
    if ($clVersion) {
        Write-Host "编译器: $clVersion"
    }

    $msbuildVersion = & "msbuild.exe" "-version" 2>&1
    if ($msbuildVersion) {
        Write-Host "MSBuild: $($msbuildVersion -join ' ')"
    }
}
catch {
    Write-Warning "验证工具时出错: $($_.Exception.Message)"
}