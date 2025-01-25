import 'dart:io';
import 'dart:async';
import 'package:image/image.dart';

import 'log_untls.dart';

/// 无损压缩图片并输出日志，显示前后大小对比和进度条
Future<void> compressImages() async {
  final directoryPath = Directory.current.path;
  final directory = Directory(directoryPath);

  if (!directory.existsSync()) {
    logError('Error: Directory "$directoryPath" does not exist.');
    exit(1);
  }

  logInfo('Starting to compress all images in directory: $directoryPath');

  final imageFiles = directory.listSync(recursive: true).whereType<File>().where((file) => _isImageFile(file.path)).toList();

  if (imageFiles.isEmpty) {
    logWarning('No image files found in the directory or its subdirectories.');
    return;
  }

  logInfo('Found ${imageFiles.length} image files.');

  final List<Map<String, dynamic>> fileStats = [];
  int processedCount = 0;
  final progress = StreamController<Map<String, dynamic>>();

  // 显示进度条
  progress.stream.listen((data) {
    processedCount++;
    final fileName = data['fileName'];
    final originalSize = data['originalSize'];
    final compressedSize = data['compressedSize'];
    final compressionRatio = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(2);

    logInfo('[$processedCount/${imageFiles.length}] Compressed: $fileName | Original: ${_formatBytes(originalSize)} | Compressed: ${_formatBytes(compressedSize)} | Reduced: $compressionRatio%');
    _showProgress(processedCount, imageFiles.length);
  });

  // 并发处理
  await Future.wait(imageFiles.map((file) async {
    final result = await _compressFileInIsolate(file, progress);
    fileStats.add(result); // 保存每个文件的压缩统计
  }));

  await progress.close();

  logSuccess('\nCompleted compressing ${imageFiles.length} images.');

  // 显示所有文件的压缩前后对比
  _showCompressionSummary(fileStats);
}

/// 检查文件是否为图片
bool _isImageFile(String path) {
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'];
  return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
}

/// 无损压缩文件的逻辑
Future<Map<String, dynamic>> _compressFileInIsolate(File file, StreamController<Map<String, dynamic>> progress) async {
  final result = <String, dynamic>{};
  try {
    final originalSize = file.lengthSync();
    final image = decodeImage(file.readAsBytesSync());

    if (image == null) {
      logError('Cannot decode image: $file. The image might be corrupted or in an unsupported format.');
      result['fileName'] = file.path;
      result['originalSize'] = originalSize;
      result['compressedSize'] = originalSize;
      result['reason'] = 'Corrupted or unsupported image format';
      return result;
    }

    // 使用 PNG 或 JPEG 格式压缩
    List<int> compressedBytes;
    if (file.path.toLowerCase().endsWith('.png')) {
      compressedBytes = encodePng(image, level: 9); // PNG 最大压缩级别
    } else if (file.path.toLowerCase().endsWith('.jpg') || file.path.toLowerCase().endsWith('.jpeg')) {
      compressedBytes = encodeJpg(image, quality: 85); // JPEG 质量
    } else {
      result['fileName'] = file.path;
      result['originalSize'] = originalSize;
      result['compressedSize'] = originalSize;
      result['reason'] = 'Not supported format for compression';
      return result;
    }

    await file.writeAsBytes(compressedBytes);
    final compressedSize = file.lengthSync();
    result['fileName'] = file.path;
    result['originalSize'] = originalSize;
    result['compressedSize'] = compressedSize;
    result['reason'] = ''; // 成功
  } catch (e) {
    logError('Failed to compress file: ${file.path}. Error: $e');
    result['fileName'] = file.path;
    result['originalSize'] = 0;
    result['compressedSize'] = 0;
    result['reason'] = 'Error during compression, possibly due to file size or format issues';
  }
  progress.add(result);
  return result;
}

/// 显示进度条
void _showProgress(int current, int total) {
  final percentage = (current / total * 100).toStringAsFixed(1);
  stdout.write('\rProgress: $current/$total ($percentage%)');
}

/// 格式化字节数
String _formatBytes(int bytes) {
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  int i = 0;
  double size = bytes.toDouble();

  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }

  return '${size.toStringAsFixed(2)} ${suffixes[i]}';
}

void _showCompressionSummary(List<Map<String, dynamic>> fileStats) {
  logInfo('\n\n--- Compression Summary ---');
  num totalOriginalSize = 0;
  num totalCompressedSize = 0;

  for (var stat in fileStats) {
    final fileName = stat['fileName'];
    final originalSize = stat['originalSize'];
    final compressedSize = stat['compressedSize'];
    final reason = stat['reason'];

    if (reason.isNotEmpty) {
      logWarning('Skipped: $fileName | Reason: $reason');
    } else {
      totalOriginalSize += originalSize;
      totalCompressedSize += compressedSize;
      final compressionRatio = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(2);
      logInfo('$fileName: Original: ${_formatBytes(originalSize)} | Compressed: ${_formatBytes(compressedSize)} | Reduced: $compressionRatio%');
    }
  }

  final totalReduction = ((1 - totalCompressedSize / totalOriginalSize) * 100).toStringAsFixed(2);
  logSuccess('\nTotal: Original: ${_formatBytes(totalOriginalSize.toInt())} | Compressed: ${_formatBytes(totalCompressedSize.toInt())} | Total Reduced: $totalReduction%');
}
