/// Dio-based HTTP client wrapper for the CloudNote API.
library;

import 'package:dio/dio.dart';
import '../config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;

  late Dio dio;
  static const _keyHeader = 'X-CloudNote-Key';

  ApiClient._() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 120),
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final headers = AppConfig.authHeaders;
      if (headers.isNotEmpty) {
        options.headers[_keyHeader] = headers[_keyHeader];
      }
      handler.next(options);
    }));
  }

  String get _base => AppConfig.apiBase;

  // ── Health ──
  Future<bool> checkHealth() async {
    try {
      final res = await dio.get('$_base/health');
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Folders ──
  Future<List<Map<String, dynamic>>> listFolders({String? parentId}) async {
    final res = await dio.get('$_base/folders',
        queryParameters: parentId != null ? {'parent_id': parentId} : null);
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> createFolder(String name, {String? parentId}) async {
    final res = await dio.post('$_base/folders', data: {
      'name': name,
      if (parentId != null) 'parent_id': parentId,
    });
    return Map<String, dynamic>.from(res.data);
  }

  Future<void> renameFolder(String id, String name) async {
    await dio.put('$_base/folders/$id', data: {'name': name});
  }

  Future<void> deleteFolder(String id) async {
    await dio.delete('$_base/folders/$id');
  }

  // ── Files ──
  Future<List<Map<String, dynamic>>> listFiles({String? folderId}) async {
    final res = await dio.get('$_base/files',
        queryParameters: folderId != null ? {'folder_id': folderId} : null);
    return List<Map<String, dynamic>>.from(res.data);
  }

  Future<Map<String, dynamic>> uploadFile(
    String filePath,
    String fileName, {
    String? folderId,
    void Function(int, int)? onProgress,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (folderId != null) 'folder_id': folderId,
    });
    final res = await dio.post('$_base/files/upload',
        data: formData, onSendProgress: onProgress);
    return Map<String, dynamic>.from(res.data);
  }

  String downloadUrl(String fileId) => '$_base/files/$fileId/download';

  Map<String, String> get authHeaders => AppConfig.authHeaders;

  Future<String> fetchText(String fileId) async {
    final res = await dio.get(
      downloadUrl(fileId),
      options: Options(responseType: ResponseType.plain),
    );
    return res.data?.toString() ?? '';
  }

  Future<int> pdfPageCount(String fileId) async {
    final res = await dio.get('$_base/files/$fileId/render/pages');
    final pages = res.data['pages'];
    if (pages is int) return pages;
    if (pages is String) return int.tryParse(pages) ?? 0;
    return 0;
  }

  String pdfPageUrl(String fileId, int page) =>
      '$_base/files/$fileId/render/page/$page';

  Future<void> downloadFile(String fileId, String savePath,
      {void Function(int, int)? onProgress}) async {
    await dio.download(downloadUrl(fileId), savePath,
        onReceiveProgress: onProgress);
  }

  Future<void> deleteFile(String id) async {
    await dio.delete('$_base/files/$id');
  }

  // ── Browse ──
  Future<Map<String, dynamic>> browse({String? folderId}) async {
    final res = await dio.get('$_base/browse',
        queryParameters: folderId != null ? {'folder_id': folderId} : null);
    return Map<String, dynamic>.from(res.data);
  }

  // ── OCR ──
  Future<Map<String, dynamic>> submitOcr(String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await dio.post('$_base/ocr/submit', data: formData);
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> ocrStatus(String taskId) async {
    final res = await dio.get('$_base/ocr/$taskId/status');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> ocrResults(String taskId) async {
    final res = await dio.get('$_base/ocr/$taskId/results');
    return Map<String, dynamic>.from(res.data);
  }
}
