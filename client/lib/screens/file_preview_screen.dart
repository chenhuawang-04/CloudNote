import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../models/file_item.dart';
import '../services/api_client.dart';
import '../services/download_service.dart';

class FilePreviewScreen extends StatefulWidget {
  final FileItem file;

  const FilePreviewScreen({super.key, required this.file});

  @override
  State<FilePreviewScreen> createState() => _FilePreviewScreenState();
}

class _FilePreviewScreenState extends State<FilePreviewScreen> {
  bool _downloading = false;
  String? _markdown;
  String? _mdError;
  int? _pdfPages;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    if (widget.file.isMarkdown) {
      _loadMarkdown();
    } else if (widget.file.isPdf) {
      _loadPdfPages();
    }
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      if (Platform.isAndroid) {
        final bytes = await ApiClient().downloadBytes(widget.file.id);
        await DownloadService.saveToDownloads(
          bytes,
          fileName: widget.file.name,
          mimeType: widget.file.mimeType,
        );
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Saved to Downloads')));
        }
      } else {
        final savePath = await _pickSavePath();
        if (savePath == null || savePath.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('No save location selected')));
          }
          setState(() => _downloading = false);
          return;
        }
        await ApiClient().downloadFile(widget.file.id, savePath);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Saved to: $savePath')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    }
    setState(() => _downloading = false);
  }

  Future<String?> _pickSavePath() async {
    return FilePicker.platform.saveFile(
      dialogTitle: 'Save to',
      fileName: widget.file.name,
    );
  }


  Future<void> _loadMarkdown() async {
    try {
      final text = await ApiClient().fetchText(widget.file.id);
      if (mounted) {
        setState(() => _markdown = text);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _mdError = e.toString());
      }
    }
  }

  Future<void> _loadPdfPages() async {
    try {
      final pages = await ApiClient().pdfPageCount(widget.file.id);
      if (mounted) {
        setState(() => _pdfPages = pages);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pdfError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = widget.file.isImage;
    final isMarkdown = widget.file.isMarkdown;
    final isPdf = widget.file.isPdf;
    final previewUrl = ApiClient().thumbnailUrl(widget.file.id);

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
              child: Center(
                child: Image.network(
                  previewUrl,
                  headers: ApiClient().authHeaders,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 64),
                ),
              ),
            )
          : isMarkdown
              ? _buildMarkdown()
              : isPdf
                  ? _buildPdfPages()
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

  Widget _buildMarkdown() {
    if (_mdError != null) {
      return Center(child: Text('加载失败: $_mdError'));
    }
    if (_markdown == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Markdown(
      data: _markdown ?? '',
      selectable: true,
      padding: const EdgeInsets.all(16),
    );
  }

  Widget _buildPdfPages() {
    if (_pdfError != null) {
      return Center(child: Text('加载失败: $_pdfError'));
    }
    final pages = _pdfPages;
    if (pages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pages == 0) {
      return const Center(child: Text('PDF 无可渲染页面'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pages,
      itemBuilder: (context, index) {
        final page = index + 1;
        final imgUrl = ApiClient().pdfPageUrl(widget.file.id, page);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Image.network(
            imgUrl,
            headers: ApiClient().authHeaders,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const SizedBox(height: 120, child: Center(child: Text('页面加载失败'))),
          ),
        );
      },
    );
  }
}
