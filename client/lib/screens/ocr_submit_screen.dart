import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/ocr_task_store.dart';
import 'ocr_tasks_screen.dart';

class OcrSubmitScreen extends StatefulWidget {
  const OcrSubmitScreen({super.key});

  @override
  State<OcrSubmitScreen> createState() => _OcrSubmitScreenState();
}

class _OcrSubmitScreenState extends State<OcrSubmitScreen> {
  final _ocrSvc = OcrService();
  String? _imagePath;
  String? _imageName;
  bool _submitting = false;
  String _statusText = '';

  Future<void> _pickFromGallery() async {
    // Use image_picker on Android, file_picker on desktop
    if (Platform.isAndroid) {
      final picker = ImagePicker();
      final img = await picker.pickImage(source: ImageSource.gallery);
      if (img != null) {
        setState(() {
          _imagePath = img.path;
          _imageName = img.name;
        });
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _imagePath = result.files.single.path;
          _imageName = result.files.single.name;
        });
      }
    }
  }

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.camera);
    if (img != null) {
      setState(() {
        _imagePath = img.path;
        _imageName = img.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_imagePath == null) return;

    setState(() {
      _submitting = true;
      _statusText = '正在提交...';
    });

    try {
      final task = await _ocrSvc.submit(_imagePath!, _imageName ?? 'image.jpg');
      OcrTaskStore.instance.addTask(task.taskId);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _statusText = '已提交，后台识别中';
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _statusText = '提交失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OCR 识题')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_imagePath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_imagePath!),
                      height: 300, fit: BoxFit.contain),
                ),
                const SizedBox(height: 8),
                Text(_imageName ?? '', style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
              ] else ...[
                const Icon(Icons.document_scanner, size: 80, color: Colors.blueGrey),
                const SizedBox(height: 16),
                const Text('选择一张含题目的图片', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 24),
              ],

              if (!_submitting) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library),
                      label: const Text('从相册选择'),
                      onPressed: _pickFromGallery,
                    ),
                    const SizedBox(width: 12),
                    if (Platform.isAndroid)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('拍照'),
                        onPressed: _pickFromCamera,
                      ),
                  ],
                ),
                if (_imagePath != null) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('开始识别'),
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ] else ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(_statusText),
              ],

              if (_statusText.isNotEmpty && !_submitting) ...[
                const SizedBox(height: 16),
                Text(_statusText, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text('查看进度'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OcrTasksScreen()),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
