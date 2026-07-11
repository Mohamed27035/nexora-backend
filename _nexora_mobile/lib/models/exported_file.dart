import 'dart:typed_data';

class ExportedFile {
  final Uint8List bytes;
  final String filename;
  final String? mimeType;

  const ExportedFile({
    required this.bytes,
    required this.filename,
    this.mimeType,
  });
}
