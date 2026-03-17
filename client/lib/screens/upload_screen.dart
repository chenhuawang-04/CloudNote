import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/file_service.dart';

class UploadScreen extends StatefulWidget {
  final String? folderId;

  const UploadScreen({super.key, this.folderId});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final _fileSvc = FileService();
  bool _uploading = false;
  double _progress = 0;
  String _statusText = '';

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _uploading = true;
      _statusText = '准备上传...';
    });

    for (int i = 0; i < result.files.length; i++) {
      final pf = result.files[i];
      if (pf.path == null) continue;

      setState(() => _statusText = '正在上传 (${i + 1}/${result.files.length}) ${pf.name}');
      try {
        await _fileSvc.upload(
          pf.path!,
          pf.name,
          folderId: widget.folderId,
          onProgress: (sent, total) {
            setState(() => _progress = total > 0 ? sent / total : 0);
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('上传失败: ${pf.name} - $e')));
        }
      }
    }

    setState(() {
      _uploading = false;
      _statusText = '上传完成';
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('全部上传完成')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('上传文件')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _uploading ? Icons.cloud_upload : Icons.upload_file,
                size: 80,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 24),
              if (_uploading) ...[
                LinearProgressIndicator(value: _progress),
                const SizedBox(height: 12),
                Text(_statusText),
              ] else ...[
                const Text('选择文件进行上传', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择文件'),
                  onPressed: _pickAndUpload,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
