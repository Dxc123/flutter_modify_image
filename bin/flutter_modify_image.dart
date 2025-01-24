import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';

void main(List<String> args) async {
  // 获取用户的确认命令
  if (!_validateCommand()) {
    logError('Invalid command, aborting operation.');
    exit(1); // 退出程序
  }

  final directoryPath = Directory.current.path;
  final directory = Directory(directoryPath);

  if (!directory.existsSync()) {
    logError('Error: Directory "$directoryPath" does not exist.');
    exit(1);
  }

  logInfo('Starting to modify MD5 for images in directory: $directoryPath');

  final imageFiles = directory.listSync().where((entity) => entity is File && _isImageFile(entity.path)).cast<File>().toList();

  if (imageFiles.isEmpty) {
    logWarning('No image files found in the current directory.');
    return;
  }

  logInfo('Found ${imageFiles.length} image files.');

  var processedCount = 0;
  for (var imageFile in imageFiles) {
    try {
      await _modifyImageMD5(imageFile);
      processedCount++;
      _showProgress(processedCount, imageFiles.length);
    } catch (e) {
      logError('Failed to modify MD5 for image: ${imageFile.path}. Error: $e');
    }
  }

  logSuccess('\nCompleted modifying MD5 for ${imageFiles.length} images.');
}

/// 验证命令是否有效
bool _validateCommand() {
  // 提示用户输入命令
  stdout.write('请输入命令 "md5" 执行操作：');
  final input = stdin.readLineSync()?.trim();

  // 如果输入为 "md5" 则继续操作，否则退出
  if (input != null && input.toLowerCase() == 'md5') {
    return true;
  } else {
    return false;
  }
}

/// 检查文件是否为图片文件
bool _isImageFile(String path) {
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'];
  return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
}

/// 修改图片的 MD5 值
Future<void> _modifyImageMD5(File imageFile) async {
  final originalMD5 = await _calculateMD5(imageFile);

  final content = await imageFile.readAsBytes();

  // 生成随机字节数据
  final random = Random();
  final randomBytes = List<int>.generate(8, (_) => random.nextInt(256));

  // 添加随机字节数据到图片末尾
  final modifiedContent = BytesBuilder()
    ..add(content)
    ..add(randomBytes);

  // 写回文件，覆盖原内容
  await imageFile.writeAsBytes(modifiedContent.toBytes());

  final modifiedMD5 = await _calculateMD5(imageFile);

  logInfo('MD5 Before: $originalMD5');
  logInfo('MD5 After: $modifiedMD5');
}

/// 计算文件的 MD5 值
Future<String> _calculateMD5(File file) async {
  final bytes = await file.readAsBytes();
  final digest = md5.convert(bytes);
  return digest.toString();
}

/// 显示进度条
void _showProgress(int current, int total) {
  final percentage = (current / total * 100).toStringAsFixed(1);
  stdout.write('\rProgress: $current/$total ($percentage%)');
}

/// 日志输出工具（带颜色）
void logInfo(String message) {
  print('\x1B[34m[INFO] $message\x1B[0m'); // 蓝色
}

void logSuccess(String message) {
  print('\x1B[32m[SUCCESS] $message\x1B[0m'); // 绿色
}

void logWarning(String message) {
  print('\x1B[33m[WARNING] $message\x1B[0m'); // 黄色
}

void logError(String message) {
  print('\x1B[31m[ERROR] $message\x1B[0m'); // 红色
}
