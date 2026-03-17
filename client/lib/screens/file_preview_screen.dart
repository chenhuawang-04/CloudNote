import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';

class FilePreviewScreen extends StatefulWidget {
  final FileItem file;

  const FilePreviewScreen({super.key, required this.file});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${widget.file.name}';
      await ApiClient().downloadFile(widget.file.id, savePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已保存到: $savePath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    }
    setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.file.isImage;
    final url = ApiClient().downloadUrl(widget.file.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        actions: [
          IconButton(
            icon: _downloading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            onPressed: _downloading ? null : _download,
            tooltip: '下载',
          ),
        ],
      ),
      body: isImage
          ? InteractiveViewer(
              child: Center(child: Image.network(url, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64))),
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.insert_drive_file, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 16),
                  Text(widget.file.name, style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  Text(widget.file.sizeStr),
                  Text(widget.file.mimeType ?? ''),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('下载文件'),
                    onPressed: _downloading ? null : _download,
                  ),
                ],
              ),
            ),
    );
  }
}
