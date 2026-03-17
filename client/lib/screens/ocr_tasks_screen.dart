import 'package:flutter/material.dart';

import '../models/ocr_task.dart';
import '../services/ocr_task_store.dart';
import 'ocr_result_screen.dart';

class OcrTasksScreen extends StatelessWidget {
  const OcrTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = OcrTaskStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('识别进度'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: store.refreshAll,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<OcrTask>>(
        valueListenable: store.tasks,
        builder: (context, tasks, _) {
          if (tasks.isEmpty) {
            return const Center(child: Text('暂无识别任务'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final t = tasks[index];
              return _TaskTile(task: t);
            },
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final OcrTask task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context) {
    final store = OcrTaskStore.instance;
    final status = _statusText(task);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text('任务 ${task.taskId.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(status),
            if (task.error != null && task.error!.isNotEmpty)
              Text('错误: ${task.error}',
                  style: const TextStyle(color: Colors.red)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.isDone)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: '查看结果',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OcrResultScreen(taskId: task.taskId),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '移除',
              onPressed: () => store.removeTask(task.taskId),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(OcrTask task) {
    if (task.progressMsg != null && task.progressMsg!.isNotEmpty) {
      return task.progressMsg!;
    }
    switch (task.status) {
      case 'pending':
        return '等待处理';
      case 'processing':
        return '处理中';
      case 'done':
        return '完成';
      case 'failed':
        return '失败';
      default:
        return task.status;
    }
  }
}
