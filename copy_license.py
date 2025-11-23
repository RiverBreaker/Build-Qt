import os
import shutil
import argparse
import logging
from pathlib import Path

# 初始化 logger
logger = logging.getLogger(__name__)

# --- 核心配置 ---

# 1. 强制保留的文件名 (白名单，优先级最高)
ALWAYS_KEEP_FILES = {
    'licenserule.json',      # Qt 归属规则定义 (重要元数据)
    'license_template.txt',  # 模板
    'patents',               # 专利声明
    'notice',                # 通告
    'third_party_licenses',  # 汇总
    'credits',               # 致谢
    'authors',               # 作者
    'copyright',             # 版权
}

# 2. 需要忽略的目录名称 (新增：过滤工具、构建系统、测试套件、特定语言绑定)
# 如果文件路径中包含这些文件夹名，将直接被跳过
IGNORE_DIRECTORIES = {
    # 测试相关
    'test', 'tests', 'testing', 'unittest', 'unittests',
    'testdata', 'fixtures', 'snapshots', 'test_dir', 'test_dir_invalid_metadata',
    'mock', 'mocks', 'fuzz', 'fuzzers', 'bench', 'benchmark', 'benchmarks',

    # 构建工具与脚本 (通常不随软件分发)
    'build', 'buildtools', 'cmake', 'mkspecs', 'tools', 'devtools',
    'gn', 'gyp', 'generator', 'templates', 'scripts', 'infra',

    # 特定的庞大测试/遥测工具
    'catapult', 'telemetry',

    # 文档
    'doc', 'docs', 'documentation', 'man',

    # 示例与依赖
    'examples', 'example', 'demo', 'demos',
    'node_modules',

    # 冗余的语言绑定源码目录 (避免 material_color_utilities 等组件重复收集)
    'java', 'dart', 'swift', 'typescript', 'kotlin'
}

# 3. 需要忽略的扩展名
IGNORE_EXTENSIONS = {
    # 二进制/媒体
    '.png', '.jpg', '.gif', '.ico', '.svg', '.exe', '.dll', '.so', '.a', '.o', '.obj', '.pyc', '.class', '.bin', '.dex',
    # 源代码
    '.cpp', '.c', '.h', '.hpp', '.cc', '.cxx', '.m', '.mm', '.java', '.cs', '.py', '.js', '.ts', '.sh', '.bat', '.pl', '.go', '.rs', '.php', '.kt', '.swift',
    # Web 前端
    '.html', '.css', '.scss', '.less',
    # 构建与配置
    '.cmake', '.pro', '.pri', '.qbs', '.gn', '.gni', '.ninja', '.mk', '.cfg', '.conf', '.yapf', '.pyl', '.gradle',
    '.build', '.vanilla', '.prf', '.mojom', '.idl', '.inc', '.ipp', '.exp', '.abilist', '.in', '.qrc', '.ini', '.qdoc', '.exclude',
    '.json', '.yaml', '.yml', '.toml', '.xml', '.data',
    # 版本控制与补丁
    '.patch', '.diff', '.gitignore', '.gitattributes', '.sha1', '.dummy', '.cipd',
    # 压缩包
    '.zip', '.tar', '.gz', '.7z', '.rar'
}

def setup_logging(output_dir, verbose_console):
    """配置双路日志"""
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG)
    root_logger.handlers = []

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')

    # 控制台 Handler
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    console_handler.setLevel(logging.DEBUG if verbose_console else logging.INFO)
    root_logger.addHandler(console_handler)

    # 文件 Handler
    log_file_path = Path(output_dir) / "collection_log.txt"
    try:
        file_handler = logging.FileHandler(log_file_path, encoding='utf-8', mode='w')
        file_handler.setFormatter(formatter)
        file_handler.setLevel(logging.DEBUG)
        root_logger.addHandler(file_handler)
        return log_file_path
    except Exception as e:
        print(f"警告: 无法创建日志文件 - {e}")
        return None

def is_test_or_irrelevant_path(file_path):
    """检查路径是否包含测试或无关目录"""
    parts = set(part.lower() for part in file_path.parent.parts)
    if not parts.isdisjoint(IGNORE_DIRECTORIES):
        return True
    return False

def is_license_file(file_path):
    """
    智能识别许可证文件 (强力去噪版 v3)
    """
    filename = file_path.name.lower()
    parent_dir = file_path.parent.name.lower()
    suffix = file_path.suffix.lower()

    # --- 规则 0: 路径检查 ---
    if is_test_or_irrelevant_path(file_path):
        return False

    # --- 规则 1: 过滤 Android/Chromium 构建标记 ---
    # 过滤 MODULE_LICENSE_MIT 等空文件
    if filename.startswith('module_license'):
        return False

    # --- 规则 2: 绝对白名单 (优先级最高) ---
    if filename in ALWAYS_KEEP_FILES:
        return True

    # --- 规则 3: 绝对黑名单检查 ---
    if suffix in IGNORE_EXTENSIONS:
        return False

    # 额外检查：防止怪异文件名绕过 suffix 检查
    if any(filename.endswith(ext) for ext in IGNORE_EXTENSIONS):
        return False

    # --- 规则 4: 排除 C++ 标准库头文件误判 ---
    if filename == 'exception' and ('include' in parent_dir or 'std' in parent_dir):
        return False

    # --- 规则 5: 特殊文件名检查 (精确匹配) ---
    exact_matches = {
        'license', 'license.txt', 'license.md', 'license.rst',
        'copying', 'copying.txt', 'copying.md',
        'copyright', 'copyright.txt',
        'licensing', 'licensing.txt',
        'notice.txt', 'patents.txt',
        'license.webview', 'license.fdlibm', 'license.v8', 'license.chromium', 'license.chromium_os',
        'license-mit', 'license-apache', 'license-zlib', 'license-bsd'
    }
    if filename in exact_matches:
        return True

    # --- 规则 6: 检查 LICENSES 目录 ---
    if parent_dir == 'licenses':
        if filename == 'owners':
            return False
        return True

    # --- 规则 7: 模糊匹配 ---
    if filename.startswith(('license', 'copying')):
        # 再次检查是否是代码文件 (防止 license.js 等)
        if suffix in IGNORE_EXTENSIONS:
            return False
        return True

    if 'license' in filename:
        if suffix in IGNORE_EXTENSIONS:
            return False
        return True

    # --- 规则 8: Exception 处理 (严格模式) ---
    if 'exception' in filename:
        negative_keywords = ['test', 'spec', 'mode', 'common', 'flaky', 'cpp', 'java', 'py', 'dom', 'mojom', 'h']
        if any(keyword in filename for keyword in negative_keywords):
            return False

        if ('gpl' in filename or
            'llvm' in filename or
            'gcc' in filename or
            'classpath' in filename or
            filename.startswith('class-path-exception') or
            filename.startswith('license-exception')):
            return True

        return False

    return False

def collect_license_files(source_dir, output_dir):
    """收集所有许可证文件到输出目录"""
    source_path = Path(source_dir).resolve()
    output_path = Path(output_dir).resolve()
    output_path.mkdir(parents=True, exist_ok=True)

    collected_files = 0
    skipped_files = 0
    ignored_count = 0

    for root, _, files in os.walk(source_path):
        current_dir_name = Path(root).name.lower()
        # 顶层目录快速过滤
        if current_dir_name in IGNORE_DIRECTORIES:
            continue

        for file in files:
            file_path = Path(root) / file

            if is_license_file(file_path):
                try:
                    rel_path = file_path.relative_to(source_path)
                except ValueError:
                    continue

                dest_path = output_path / rel_path
                dest_path.parent.mkdir(parents=True, exist_ok=True)

                try:
                    shutil.copy2(file_path, dest_path)
                    collected_files += 1
                    logger.debug(f"已收集: {rel_path}")
                except Exception as e:
                    logger.error(f"复制失败 {file_path}: {str(e)}")
                    skipped_files += 1
            else:
                ignored_count += 1

    # 生成总结报告
    report_path = output_path / "COLLECTION_REPORT.txt"
    try:
        with open(report_path, 'w', encoding='utf-8') as report:
            report.write(f"Qt许可证文件收集报告\n")
            report.write(f"========================\n")
            report.write(f"源码目录: {source_path}\n")
            report.write(f"输出目录: {output_path}\n")
            report.write(f"收集文件数: {collected_files}\n")
            report.write(f"跳过/错误数: {skipped_files}\n")
            report.write(f"忽略文件数: {ignored_count}\n")
            report.write(f"收集时间: {os.path.getmtime(report_path) if report_path.exists() else 'Now'}\n")

        logger.info("-" * 50)
        logger.info(f"收集完成! 共收集 {collected_files} 个文件")
        logger.info(f"详细日志已保存至: {output_path / 'collection_log.txt'}")
        logger.info(f"总结报告已保存至: {report_path}")

    except Exception as e:
        logger.error(f"无法写入报告文件: {e}")

def main():
    parser = argparse.ArgumentParser(description='收集Qt源码中的所有许可证文件 (强力去噪版v3)')
    parser.add_argument('source_dir', help='Qt源码根目录路径')
    parser.add_argument('output_dir', help='输出目录路径')
    parser.add_argument('-v', '--verbose', action='store_true', help='在控制台显示详细日志')

    args = parser.parse_args()

    if not os.path.isdir(args.source_dir):
        print(f"错误: 源目录不存在 - {args.source_dir}")
        return 1

    output_path = Path(args.output_dir).resolve()
    try:
        output_path.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        print(f"错误: 无法创建输出目录 - {e}")
        return 1

    log_file = setup_logging(output_path, args.verbose)

    logger.info(f"开始收集许可证文件...")
    logger.info(f"源码目录: {args.source_dir}")
    logger.info(f"输出目录: {args.output_dir}")
    if log_file:
        logger.info(f"正在记录详细日志到: {log_file}")

    try:
        collect_license_files(args.source_dir, args.output_dir)
        return 0
    except Exception as e:
        logger.exception(f"发生未处理的异常: {str(e)}")
        return 1

if __name__ == "__main__":
    exit(main())