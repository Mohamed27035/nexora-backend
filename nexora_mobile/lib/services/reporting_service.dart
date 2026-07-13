import 'package:dio/dio.dart';

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
}
