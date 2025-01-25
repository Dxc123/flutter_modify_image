import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:image/image.dart';

import 'log_untls.dart';
import 'modify_md5.dart';

// 无损压缩图片，支持压缩算法和质量设置
Future<void> compressImages(List<String> args) async {
  final directoryPath = Directory.current.path;
  final directory = Directory(directoryPath);

  if (!directory.existsSync()) {
    logError('Error: Directory "$directoryPath" does not exist.');
    exit(1);
  }

  // 解析参数
  final quality = _parseQuality(args, defaultValue: 80);
  final compressionType = _parseCompressionType(args, defaultValue: 'png');

  logInfo('Starting to compress all images in directory: $directoryPath');
  logInfo('Using compression type: $compressionType with quality: $quality');

  final imageFiles = directory.listSync(recursive: true).whereType<File>().where((file) => _isImageFile(file.path)).toList();

  if (imageFiles.isEmpty) {
    logWarning('No image files found in the directory or its subdirectories.');
    return;
  }

  logInfo('Found ${imageFiles.length} image files.');

  const maxConcurrentIsolates = 4;
  await _processFilesWithIsolatePool(
    imageFiles,
    maxConcurrentIsolates,
    (file, progress) => _compressFileInIsolate(file, progress, quality, compressionType),
  );

  logSuccess('\nCompleted compressing ${imageFiles.length} images.');
}

/// 使用 Isolate 池处理文件
Future<void> _processFilesWithIsolatePool(
  List<File> files,
  int maxConcurrentIsolates,
  Future<void> Function(File, StreamController<Map<String, dynamic>>) isolateFunction,
) async {
  final pool = IsolatePool(maxConcurrentIsolates);
  final progress = StreamController<Map<String, dynamic>>();
  int processedCount = 0;

  progress.stream.listen((data) {
    processedCount++;
    final fileName = data['fileName'];
    final originalSize = data['originalSize'];
    final compressedSize = data['compressedSize'];
    final reason = data['reason'] ?? '';
    final compressionRatio = compressedSize > 0 ? ((1 - compressedSize / originalSize) * 100).toStringAsFixed(2) : 'N/A';

    if (compressedSize > 0) {
      logInfo('[$processedCount/${files.length}] Compressed: $fileName | Original: ${_formatBytes(originalSize)} | Compressed: ${_formatBytes(compressedSize)} | Reduced: $compressionRatio%');
    } else {
      logWarning('[$processedCount/${files.length}] Skipped: $fileName | Reason: $reason | Size: ${_formatBytes(originalSize)}');
    }
    _showProgress(processedCount, files.length);
  });

  for (final file in files) {
    pool.submitTask(() async {
      await isolateFunction(file, progress);
    });
  }

  await pool.close();
  await progress.close();
}

/// 使用 Isolate 压缩文件，输出详细日志
Future<void> _compressFileInIsolate(File file, StreamController<Map<String, dynamic>> progress, int quality, String compressionType) async {
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(_isolateCompressFile, [file.path, receivePort.sendPort, quality, compressionType]);

  await for (var message in receivePort) {
    if (message is Map<String, dynamic>) {
      progress.add(message);
      receivePort.close();
      isolate.kill();
      break;
    }
  }
}

/// Isolate 压缩文件逻辑
void _isolateCompressFile(List args) async {
  final filePath = args[0] as String;
  final sendPort = args[1] as SendPort;
  final quality = args[2] as int;
  final compressionType = args[3] as String;

  try {
    final file = File(filePath);
    final originalSize = file.lengthSync();
    final image = decodeImage(file.readAsBytesSync());

    if (image == null) {
      sendPort.send({'fileName': filePath, 'originalSize': originalSize, 'compressedSize': 0, 'reason': 'Unsupported format'});
      return;
    }

    List<int> compressedBytes;
    if (compressionType == 'png') {
      compressedBytes = encodePng(image, level: max(0, 9 - (quality ~/ 10)));
    } else if (compressionType == 'jpg' || compressionType == 'jpeg') {
      compressedBytes = encodeJpg(image, quality: quality);
    } else {
      sendPort.send({'fileName': filePath, 'originalSize': originalSize, 'compressedSize': 0, 'reason': 'Invalid compression type'});
      return;
    }

    if (compressedBytes.length >= originalSize) {
      sendPort.send({'fileName': filePath, 'originalSize': originalSize, 'compressedSize': 0, 'reason': 'No significant size reduction'});
      return;
    }

    await file.writeAsBytes(compressedBytes);
    final compressedSize = file.lengthSync();
    sendPort.send({'fileName': filePath, 'originalSize': originalSize, 'compressedSize': compressedSize});
  } catch (e) {
    sendPort.send({'fileName': filePath, 'originalSize': 0, 'compressedSize': 0, 'reason': e.toString()});
  }
}

/// 解析压缩质量
int _parseQuality(List<String> args, {int defaultValue = 80}) {
  final qualityArg = args.firstWhere((arg) => arg.startsWith('--quality='), orElse: () => "");
  if (qualityArg.isNotEmpty) {
    final qualityValue = int.tryParse(qualityArg.split('=').last);
    if (qualityValue != null && qualityValue > 0 && qualityValue <= 100) {
      return qualityValue;
    }
  }
  return defaultValue;
}

/// 解析压缩类型
String _parseCompressionType(List<String> args, {String defaultValue = 'png'}) {
  final typeArg = args.firstWhere((arg) => arg.startsWith('--type='), orElse: () => "");
  if (typeArg.isNotEmpty) {
    final typeValue = typeArg.split('=').last.toLowerCase();
    if (['png', 'jpg', 'jpeg'].contains(typeValue)) {
      return typeValue;
    }
  }
  return defaultValue;
}

/// 检查文件是否为图片
bool _isImageFile(String path) {
  final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.webp'];
  return imageExtensions.any((ext) => path.toLowerCase().endsWith(ext));
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
