# Build-Qt

这是一个使用 GitHub Actions 自动化构建 Qt 库的项目，旨在简化在不同平台和配置下获取 Qt 构建产物的流程。

## ✨ 功能特性

- **自动化构建**：完全基于 GitHub Actions，无需本地环境配置。
- **多平台支持**：当前主要支持 Windows 平台的构建。由于 GitHub Actions 免费 Runner 的磁盘空间限制（通常约为 14 GB），完整的 Qt 源码及构建过程会超出此限制，因此暂未启用 Linux 和 macOS 的构建工作流。
- **灵活配置**：
  - 可自定义 Qt 版本（主版本、次版本、补丁版本）。
  - 支持动态链接库（Shared）和静态链接库（Static）构建。
  - **注意**：为节约构建时间和磁盘空间，静态库（Static）构建默认仅生成 `Release` 版本。
  - 支持多种构建类型，如 `Debug`、`Release` 和 `RelWithDebInfo`。
- **缓存优化**：利用 GitHub Actions 的缓存机制，缓存 Qt 源码，加速重复构建。
- **自动发布**：构建成功后，自动创建 Git 标签和 GitHub Release，并将构建产物上传为 7z/tar.gz 压缩包。

## 🚀 如何使用

1.  **Fork 本仓库**：将此项目 Fork 到您自己的 GitHub 账户下。
2.  **启用 Actions**：确保您的 Fork 仓库已启用 GitHub Actions。
3.  **手动触发工作流**：
    - 进入仓库的 “Actions” 页面。
    - 从左侧列表中选择一个您需要的工作流（例如 `Build Qt 6.x.x -shared (Windows VS2022)`）。
    - 点击 “Run workflow” 按钮。
    - 在弹出的表单中，输入您想要构建的 Qt 版本号（例如主次版本 `6.9`，补丁版本 `0`）。
    - 点击 “Run workflow” 开始构建。
    - **注意**：构建过程耗时较长，根据配置不同，大约需要 2 到 6 小时。
4.  **下载构建产物**：
    - 工作流执行完毕后，进入仓库的 “Releases” 页面。
    - 找到对应版本号的 Release（例如 `v6.9.0-shared`）。
    - 在 “GitHub release” 中下载您需要的构建产物压缩包。

## 🛠️ 工作流说明

项目包含多个工作流文件，位于 `.github/workflows` 目录下，分别对应不同的目标平台、编译器和构建类型。

**命名约定**：`build-qt-<链接方式>-<平台>-<编译器/工具链>(配置).yml`

- **链接方式**：`shared` 或 `static`。
- **平台**：`win`、`linux` 或 `mac`。
- **编译器/工具链**：`msvc2022`、`mingw64`、`gcc13` 等。
- **(配置)**：如果特定于某种配置（如 `release`），则会标注。

**示例**：

- `build-qt-shared-win-msvc2022.yml`：在 Windows (VS2022) 环境下构建 **动态链接** 的 Qt 库。
- `build-qt-static-win-mingw64(release).yml`：在 Windows (MinGW-w64) 环境下构建 **静态链接** 的 Qt 库（仅 Release）。

### 关于 Linux 和 macOS 工作流的说明

- **macOS (`build-qt-shared-mac-clang15.yml`)**: 此工作流已经过验证，可以正常在 GitHub Actions 的 macOS Runner 上运行。
- **Linux (`build-qt-shared-linux-gcc13-release.yml`)**: 此工作流已经过验证，可以正常在 GitHub Actions 的 Ubuntu Runner 上运行。
  - **注意**: 由于 Github actions 的 Ubuntu runner 的磁盘空间限制（通常约为 14 GB），Debug & RelWithDebInfo 版本并没有在本仓库中被构建
    - 如果你需要构建这两个配置的Qt, 你需要自己修改工作流文件, 并使用更大的 GitHub actions runner 来运行 或者 根据工作流文件来适配自己本地的构建环境来在本地自行构建

## 📄 许可证

本项目遵循 [MIT License](./LICENSE)。


qt-add-module.bat使用示例：
```shell
qt-add-module.bat --qt-version < qt_version > --d-fake-dir "< which_dir_will_be_subst_to_D_driver >" --qt-source-dir "< QT_SOURCE_DIR >" --add-module < QtModuleName > --qt-installed-dir "<QT_INSTALLED_DIR>" --install-dir "<QT_MODULE_WILL_INSTALL_DIR>"
```