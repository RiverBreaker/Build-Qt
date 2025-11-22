import os
import shutil
import argparse
import logging
from pathlib import Path

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def is_license_file(file_path):
    """
    智能识别许可证文件
    匹配模式:
    1. 标准许可证文件名 (不区分大小写)
    2. LICENSES目录下的所有文件
    3. 包含'license'或'copying'关键词的文件
    """
    filename = file_path.name.lower()
    parent_dir = file_path.parent.name.lower()
    
    # 标准许可证文件名
    license_names = {
        'license', 'copying', 'lgpl_exception.txt', 'gpl_exception.txt',
        'licensing', 'copyright', 'notice', 'patents', 'author'
    }
    
    # 检查标准命名
    if any(filename.startswith(name) for name in 
           ['license', 'copying', 'lgpl_exception', 'gpl_exception']) or \
       any(name in filename for name in ['license', 'copying', 'exception']):
        return True
    
    # 检查特定文件名
    if filename in license_names:
        return True
    
    # 检查LICENSES目录
    if parent_dir == 'licenses':
        return True
    
    return False

def collect_license_files(source_dir, output_dir):
    """
    收集所有许可证文件到输出目录
    
    :param source_dir: Qt源码根目录
    :param output_dir: 输出目录
    """
    source_path = Path(source_dir).resolve()
    output_path = Path(output_dir).resolve()
    
    # 创建输出目录
    output_path.mkdir(parents=True, exist_ok=True)
    logger.info(f"创建输出目录: {output_path}")
    
    collected_files = 0
    skipped_files = 0
    
    # 遍历源码目录
    for root, _, files in os.walk(source_path):
        for file in files:
            file_path = Path(root) / file
            
            # 检查是否为许可证文件
            if is_license_file(file_path):
                # 计算相对路径 (保留目录结构)
                rel_path = file_path.relative_to(source_path)
                dest_path = output_path / rel_path
                
                # 创建目标目录
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                
                try:
                    # 复制文件
                    shutil.copy2(file_path, dest_path)
                    collected_files += 1
                    logger.debug(f"已收集: {rel_path}")
                except Exception as e:
                    logger.error(f"复制失败 {file_path}: {str(e)}")
                    skipped_files += 1
    
    # 生成报告
    report_path = output_path / "COLLECTION_REPORT.txt"
    with open(report_path, 'w', encoding='utf-8') as report:
        report.write(f"Qt许可证文件收集报告\n")
        report.write(f"========================\n")
        report.write(f"源码目录: {source_path}\n")
        report.write(f"输出目录: {output_path}\n")
        report.write(f"收集文件数: {collected_files}\n")
        report.write(f"跳过文件数: {skipped_files}\n")
        report.write(f"收集时间: {report_path.stat().st_mtime}\n")
    
    logger.info(f"收集完成! 共收集 {collected_files} 个文件")
    logger.info(f"跳过 {skipped_files} 个文件")
    logger.info(f"详细报告已保存至: {report_path}")

def main():
    parser = argparse.ArgumentParser(description='收集Qt源码中的所有许可证文件')
    parser.add_argument('source_dir', help='Qt源码根目录路径')
    parser.add_argument('output_dir', help='输出目录路径')
    parser.add_argument('-v', '--verbose', action='store_true', help='显示详细日志')
    
    args = parser.parse_args()
    
    # 设置详细日志
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # 验证源目录
    if not os.path.isdir(args.source_dir):
        logger.error(f"错误: 源目录不存在 - {args.source_dir}")
        return 1
    
    logger.info(f"开始收集许可证文件...")
    logger.info(f"源码目录: {args.source_dir}")
    logger.info(f"输出目录: {args.output_dir}")
    
    try:
        collect_license_files(args.source_dir, args.output_dir)
        return 0
    except Exception as e:
        logger.exception(f"发生未处理的异常: {str(e)}")
        return 1

if __name__ == "__main__":
    exit(main())