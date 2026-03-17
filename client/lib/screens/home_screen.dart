import 'package:flutter/material.dart';
import '../models/folder_item.dart';
import '../models/file_item.dart';
import '../services/api_client.dart';
import '../widgets/folder_tile.dart';
import '../widgets/file_tile.dart';
import 'folder_screen.dart';
import 'upload_screen.dart';
import 'file_preview_screen.dart';
import 'ocr_submit_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient();
  List<FolderItem> _folders = [];
  List<FileItem> _files = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.browse();
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
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createFolder() async {
    final name = await _showInputDialog('新建文件夹', '文件夹名称');
    if (name == null || name.isEmpty) return;
    try {
      await _api.createFolder(name);
      _refresh();
    } catch (e) {
      _showError('创建失败: $e');
    }
  }

  Future<void> _renameFolder(FolderItem folder) async {
    final name = await _showInputDialog('重命名', '新名称', initial: folder.name);
    if (name == null || name.isEmpty) return;
    try {
      await _api.renameFolder(folder.id, name);
      _refresh();
    } catch (e) {
      _showError('重命名失败: $e');
    }
  }

  Future<void> _deleteFolder(FolderItem folder) async {
    final ok = await _showConfirm('删除文件夹 "${folder.name}"？\n其中的所有文件也会被删除。');
    if (ok != true) return;
    try {
      await _api.deleteFolder(folder.id);
      _refresh();
    } catch (e) {
      _showError('删除失败: $e');
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    final ok = await _showConfirm('删除文件 "${file.name}"？');
    if (ok != true) return;
    try {
      await _api.deleteFile(file.id);
      _refresh();
    } catch (e) {
      _showError('删除失败: $e');
    }
  }

  Future<String?> _showInputDialog(String title, String hint, {String? initial}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('确定')),
        ],
      ),
    );
  }

  Future<bool?> _showConfirm(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CloudNote'),
        actions: [
          IconButton(icon: const Icon(Icons.camera_alt), tooltip: 'OCR识题',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const OcrSubmitScreen()))
                  .then((_) => _refresh())),
          IconButton(icon: const Icon(Icons.settings), tooltip: '设置',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'folder',
            onPressed: _createFolder,
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'upload',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const UploadScreen()))
                .then((_) => _refresh()),
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _refresh, child: const Text('重试')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      ..._folders.map((f) => FolderTile(
                            folder: f,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => FolderScreen(folder: f)))
                                .then((_) => _refresh()),
                            onRename: () => _renameFolder(f),
                            onDelete: () => _deleteFolder(f),
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
                          child: Center(child: Text('空目录，点击右下角上传文件或创建文件夹')),
                        ),
                    ],
                  ),
                ),
    );
  }
}
