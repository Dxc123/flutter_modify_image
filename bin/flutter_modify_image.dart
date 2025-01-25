import 'dart:io';
import 'package:flutter_modify_image/image_compress.dart';
import 'package:flutter_modify_image/image_converter.dart';
import 'package:flutter_modify_image/log_untls.dart';
import 'package:flutter_modify_image/image_modify_md5.dart';

void main(List<String> args) async {
  stdout.write('请输入命令 ("md5" 或 "compress" 或 "converter") 执行操作：');
  final command = stdin.readLineSync()?.trim();
  if (command != null && command == 'md5') {
    await imagesModifyMD5();
  } else if (command == 'compress') {
    await imagesCompress();
  } else if (command == 'converter') {
    await imagesConverter();
  } else {
    logError('Invalid command. Use "md5" or "compress" or "converter".');
    exit(1);
  }
}
