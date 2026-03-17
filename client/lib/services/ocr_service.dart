import 'dart:async';
import '../models/ocr_task.dart';
import 'api_client.dart';

class OcrService {
  final _api = ApiClient();

  Future<OcrTask> submit(String filePath, String fileName) async {
    final data = await _api.submitOcr(filePath, fileName);
    return OcrTask.fromJson(data);
  }

  Future<OcrTask> getStatus(String taskId) async {
    final data = await _api.ocrStatus(taskId);
    return OcrTask.fromJson(data);
  }

  Future<OcrResult> getResults(String taskId) async {
    final data = await _api.ocrResults(taskId);
    return OcrResult.fromJson(data);
  }

  /// Poll until task is done or failed, calling [onUpdate] each time.
  Future<OcrTask> pollUntilDone(
    String taskId, {
    Duration interval = const Duration(seconds: 2),
    void Function(OcrTask)? onUpdate,
  }) async {
    while (true) {
      final task = await getStatus(taskId);
      onUpdate?.call(task);
      if (task.isDone || task.isFailed) return task;
      await Future.delayed(interval);
    }
  }
}
