import 'package:flutter/material.dart';
import '../models/folder_item.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
import 'upload_screen.dart';
import 'file_preview_screen.dart';

class FolderScreen extends StatefulWidget {
  final FolderItem folder;

  const FolderScreen({super.key, required this.folder});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final _api = ApiClient();
  List<FolderItem> _folders = [];
  List<FileItem> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final data = await _api.browse(folderId: widget.folder.id);
      setState(() {
        _folders = (data['folders'] as List)
            .map((j) => FolderItem.fromJson(j))
            .toList();
        _files = (data['files'] as List)
            .map((j) => FileItem.fromJson(j))
            .toList();
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

  Future<void> _createFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建子文件夹'),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: '名称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await _api.createFolder(name, parentId: widget.folder.id);
    _refresh();
  }

  Future<void> _deleteFile(FileItem file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认'),
        content: Text('删除 "${file.name}"？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (ok != true) return;
    await _api.deleteFile(file.id);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'subfolder',
            onPressed: _createFolder,
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'upload_sub',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) =>
                    UploadScreen(folderId: widget.folder.id)))
                .then((_) => _refresh()),
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  ..._folders.map((f) => FolderTile(
                        folder: f,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FolderScreen(folder: f)))
                            .then((_) => _refresh()),
                      )),
                  ..._files.map((f) => FileTile(
                        file: f,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FilePreviewScreen(file: f))),
                        onDownload: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => FilePreviewScreen(file: f))),
                        onDelete: () => _deleteFile(f),
                      )),
                  if (_folders.isEmpty && _files.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('空文件夹')),
                    ),
                ],
              ),
            ),
    );
  }
}
