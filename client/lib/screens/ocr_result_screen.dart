import 'package:flutter/material.dart';
import '../models/ocr_task.dart';
import '../services/ocr_service.dart';
import '../services/api_client.dart';
import 'file_preview_screen.dart';
import '../models/file_item.dart';

class OcrResultScreen extends StatefulWidget {
  final String taskId;

  const OcrResultScreen({super.key, required this.taskId});

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  final _ocrSvc = OcrService();
  OcrResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _ocrSvc.getResults(widget.taskId);
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
      }
    }
  }

  void _openFile(String? fileId, String name) {
    if (fileId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePreviewScreen(
          file: FileItem(id: fileId, name: name, size: 0, createdAt: ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('识别结果')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _result == null || _result!.questions.isEmpty
              ? const Center(child: Text('没有识别到题目'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _result!.questions.length,
                  itemBuilder: (context, index) {
                    final q = _result!.questions[index];
                    return _QuestionCard(
                      question: q,
                      onViewCrop: () => _openFile(q.cropFileId, 'q${q.index}_crop.png'),
                      onViewPdf: () => _openFile(q.pdfFileId, 'q${q.index}.pdf'),
                    );
                  },
                ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuestionResult question;
  final VoidCallback onViewCrop;
  final VoidCallback onViewPdf;

  const _QuestionCard({
    required this.question,
    required this.onViewCrop,
    required this.onViewPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  child: Text('${question.index}',
                      style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Text('第 ${question.index} 题',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(),

            // Markdown preview
            if (question.markdown.isNotEmpty) ...[
              Text(question.markdown,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, height: 1.5)),
              const SizedBox(height: 8),
            ],

            // Crop image preview
            if (question.cropFileId != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  ApiClient().thumbnailUrl(question.cropFileId!),
                  headers: ApiClient().authHeaders,
                  fit: BoxFit.fitWidth,
                  height: 150,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const SizedBox(height: 60, child: Center(child: Text('图片加载失败'))),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (question.cropFileId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('查看裁剪图'),
                    onPressed: onViewCrop,
                  ),
                if (question.pdfFileId != null)
                  TextButton.icon(
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('查看PDF'),
                    onPressed: onViewPdf,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
