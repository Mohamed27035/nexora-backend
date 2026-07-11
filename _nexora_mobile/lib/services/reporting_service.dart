import 'package:dio/dio.dart';
import 'dart:typed_data';

import '../models/exported_file.dart';
import 'api_service.dart';

class ReportingService {
  static Future<Response> getStats() async {
    return await ApiService.dio.get("reporting/stats/");
  }

  static Future<Response> getChartData() async {
    return await ApiService.dio.get("reporting/chart/");
  }

  static Future<Response> getFinancialStats() async {
    return await ApiService.dio.get("reporting/financial/");
  }

  static Future<Response> exportPdf() async {
    return await ApiService.dio.get("reporting/export-pdf/");
  }

  static Future<Response> exportTransactionsPdf() async {
    return await ApiService.dio.get("reporting/export-transactions-pdf/");
  }

  static Future<Response> exportTransactionsExcel() async {
    return await ApiService.dio.get("reporting/export-transactions-excel/");
  }

  static Future<Uint8List> exportPdfBytes() async {
    final res = await ApiService.dio.get<List<int>>(
      "reporting/export-pdf/",
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  static Future<Uint8List> exportTransactionsPdfBytes() async {
    final res = await ApiService.dio.get<List<int>>(
      "reporting/export-transactions-pdf/",
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  static Future<Uint8List> exportTransactionsExcelBytes() async {
    final res = await ApiService.dio.get<List<int>>(
      "reporting/export-transactions-excel/",
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  static Future<ExportedFile> exportPdfFile() async {
    return _downloadFile(
      endpoint: "reporting/export-pdf/",
      fallbackFilename: "report.pdf",
    );
  }

  static Future<ExportedFile> exportTransactionsPdfFile() async {
    return _downloadFile(
      endpoint: "reporting/export-transactions-pdf/",
      fallbackFilename: "transactions.pdf",
    );
  }

  static Future<ExportedFile> exportTransactionsExcelFile() async {
    return _downloadFile(
      endpoint: "reporting/export-transactions-excel/",
      fallbackFilename: "transactions.xlsx",
    );
  }

  static Future<ExportedFile> _downloadFile({
    required String endpoint,
    required String fallbackFilename,
  }) async {
    final res = await ApiService.dio.get<List<int>>(
      endpoint,
      options: Options(responseType: ResponseType.bytes),
    );

    final headers = res.headers;
    final contentDisposition = headers.value("content-disposition");
    final contentType = headers.value("content-type");

    return ExportedFile(
      bytes: Uint8List.fromList(res.data ?? const []),
      filename: _extractFilename(contentDisposition) ?? fallbackFilename,
      mimeType: contentType,
    );
  }

  static String? _extractFilename(String? contentDisposition) {
    if (contentDisposition == null || contentDisposition.isEmpty) {
      return null;
    }

    final utf8Match = RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
        .firstMatch(contentDisposition);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }

    final simpleMatch =
        RegExp(r'filename="?([^";]+)"?', caseSensitive: false).firstMatch(contentDisposition);
    return simpleMatch?.group(1);
  }
}
