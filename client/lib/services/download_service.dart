import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class DownloadService {
  DownloadService._();

  static const MethodChannel _channel = MethodChannel('cloudnote/downloads');

  static Future<String?> saveToDownloads(
    Uint8List bytes, {
    required String fileName,
    String? mimeType,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('saveToDownloads is Android-only');
    }
    final res = await _channel.invokeMethod<String>('saveToDownloads', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': mimeType,
    });
    return res;
  }
}
