import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ocr_task.dart';
import 'ocr_service.dart';

class OcrTaskStore {
  OcrTaskStore._();

  static final OcrTaskStore instance = OcrTaskStore._();

  final _service = OcrService();
  final ValueNotifier<List<OcrTask>> tasks = ValueNotifier([]);
  final Map<String, Timer> _timers = {};

  void addTask(String taskId) {
    if (_timers.containsKey(taskId)) {
      return;
    }
    _upsert(OcrTask(taskId: taskId, status: 'pending'));
    _startPolling(taskId);
  }

  void removeTask(String taskId) {
    _timers.remove(taskId)?.cancel();
    final list = List<OcrTask>.from(tasks.value);
    list.removeWhere((t) => t.taskId == taskId);
    tasks.value = list;
  }

  Future<void> refreshTask(String taskId) async {
    try {
      final task = await _service.getStatus(taskId);
      _upsert(task);
      if (task.isDone || task.isFailed) {
        _timers.remove(taskId)?.cancel();
      }
    } catch (e) {
      final existing = _find(taskId);
      if (existing != null) {
        _upsert(OcrTask(
          taskId: existing.taskId,
          status: existing.status,
          progressMsg: existing.progressMsg,
          questionCount: existing.questionCount,
          resultFolderId: existing.resultFolderId,
          error: e.toString(),
        ));
      }
    }
  }

  void refreshAll() {
    for (final t in List<OcrTask>.from(tasks.value)) {
      refreshTask(t.taskId);
    }
  }

  void _startPolling(String taskId) {
    const interval = Duration(seconds: 2);
    _timers[taskId] = Timer.periodic(interval, (_) => refreshTask(taskId));
  }

  OcrTask? _find(String taskId) {
    for (final t in tasks.value) {
      if (t.taskId == taskId) return t;
    }
    return null;
  }

  void _upsert(OcrTask task) {
    final list = List<OcrTask>.from(tasks.value);
    final idx = list.indexWhere((t) => t.taskId == task.taskId);
    if (idx >= 0) {
      list[idx] = task;
    } else {
      list.insert(0, task);
    }
    tasks.value = list;
  }
}
