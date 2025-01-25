import 'dart:io';
import 'dart:isolate';
import 'package:ansicolor/ansicolor.dart';
import 'package:image/image.dart' as img;

Future<void> imagesConverter() async {
  final color = AnsiPen()..red(bold: true);
  final green = AnsiPen()..green(bold: true);

  // 获取当前目录
  final directory = Directory.current;
  final files = directory.listSync(recursive: false);

  // 筛选出图片文件
  final imageFiles = files.where((file) {
    final extension = file.path.split('.').last.toLowerCase();
    return extension == 'png' || extension == 'webp';
  }).toList();
  if (imageFiles.isEmpty) {
    print(color('No image files found in the current directory.'));
    return;
  }

  // 创建 Isolate 处理每个图片文件
  final isolates = <Isolate>[];
  final receivePort = ReceivePort();

  for (final file in imageFiles) {
    final sendPort = receivePort.sendPort;
    final isolate = await Isolate.spawn(convertImage, [file.path, sendPort]);
    isolates.add(isolate);
  }

  // 监听 Isolate 的完成消息
  await for (final message in receivePort) {
    print(green(message));
  }

  // 等待所有 Isolate 完成
  for (final isolate in isolates) {
    isolate.kill(priority: Isolate.immediate);
  }
}

void convertImage(List<dynamic> args) {
  final filePath = args[0] as String;
  final sendPort = args[1] as SendPort;
  final color = AnsiPen()..red(bold: true);
  final green = AnsiPen()..green(bold: true);

  final inputFile = File(filePath);
  final outputFormat = 'png'; // 你可以根据需要更改输出格式

  if (!inputFile.existsSync()) {
    sendPort.send(color('Input file does not exist: $filePath'));
    return;
  }

  final bytes = inputFile.readAsBytesSync();
  print(green('Reading file... ${bytes.length} bytes'));
  final image = img.decodeImage(bytes);

  if (image == null) {
    sendPort.send(color('Failed to decode image: $filePath'));
    return;
  }

  List<int>? outputBytes;
  switch (outputFormat) {
    case 'png':
      outputBytes = img.encodePng(image);
      break;
    case 'webp':
      // 假设你已经安装了 webp 包并导入了相关库
      // outputBytes = webp.encodeLossless(image.getBytes());
      sendPort.send(color('WebP encoding is not yet supported: $filePath'));
      return;
    default:
      sendPort.send(color('Unsupported output format. Please use "png": $filePath'));
      return;
  }

  if (outputBytes.isEmpty) {
    sendPort.send(color('Failed to encode image: $filePath'));
    return;
  }

  final outputFile = File('${inputFile.path}.$outputFormat');
  outputFile.writeAsBytesSync(outputBytes);
  sendPort.send(green('Image converted and saved to ${outputFile.path}'));
}
