import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileUtils {
  static Future<Directory> _exportsDir() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final dir = Directory("${baseDir.path}${Platform.pathSeparator}exports");
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static String timestampedName(String filename) {
    final now = DateTime.now();
    final stamp =
        "${now.year}${now.month.toString().padLeft(2, "0")}${now.day.toString().padLeft(2, "0")}_"
        "${now.hour.toString().padLeft(2, "0")}${now.minute.toString().padLeft(2, "0")}${now.second.toString().padLeft(2, "0")}";
    final dotIndex = filename.lastIndexOf(".");
    if (dotIndex <= 0 || dotIndex == filename.length - 1) {
      return "${filename}_$stamp";
    }
    final name = filename.substring(0, dotIndex);
    final ext = filename.substring(dotIndex);
    return "${name}_$stamp$ext";
  }

  static Future<File> saveToTemp({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = Directory.systemTemp.createTempSync("nexora_");
    final file = File("${dir.path}${Platform.pathSeparator}$filename");
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> saveExport({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = await _exportsDir();
    final file = File("${dir.path}${Platform.pathSeparator}${timestampedName(filename)}");
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<bool> openFile(File file) async {
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

static Future<void> shareFile(
  File file, {
  String? subject,
  String? text,
}) async {
  await Share.shareXFiles(
    [XFile(file.path)],
    subject: subject,
    text: text,
  );
}
}
