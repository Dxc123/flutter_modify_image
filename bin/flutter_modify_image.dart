import 'dart:io';
import 'package:flutter_modify_image/compress_images.dart';
import 'package:flutter_modify_image/log_untls.dart';
import 'package:flutter_modify_image/modify_md5.dart';

void main(List<String> args) async {
  stdout.write('请输入命令 ("md5" 或 "compress") 执行操作：');
  final command = stdin.readLineSync()?.trim();
  if (command != null && command == 'md5') {
    await modifyImagesMD5();
  } else if (command == 'compress') {
    await compressImages();
  } else {
    logError('Invalid command. Use "md5" or "compress".');
    exit(1);
  }
}
