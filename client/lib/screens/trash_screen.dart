import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../models/folder_item.dart';
import '../services/api_client.dart';
import '../utils/time_format.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  final ApiClient _api = ApiClient();
  List<FolderItem> _folders = [];
  List<FileItem> _files = [];
  bool _loading = true;
  bool _busy = false;
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
      final data = await _api.browseTrash();
      setState(() {
        _folders = (data['folders'] as List)
            .map((json) => FolderItem.fromJson(json))
            .toList();
        _files = (data['files'] as List)
            .map((json) => FileItem.fromJson(json))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Load failed: $e';
        _loading = false;
      });
    }
  }

  Future<void> _restoreFolder(FolderItem folder) async {
    final ok = await _showConfirm(
      'Restore folder "${folder.name}" and its contents?',
      confirmLabel: 'Restore',
    );
    if (ok != true) return;

    await _runBusyAction(
      action: () => _api.restoreFolder(folder.id),
      successMessage: 'Folder restored.',
    );
  }

  Future<void> _restoreFile(FileItem file) async {
    final ok = await _showConfirm(
      'Restore file "${file.name}"?',
      confirmLabel: 'Restore',
    );
    if (ok != true) return;

    await _runBusyAction(
      action: () => _api.restoreFile(file.id),
      successMessage: 'File restored.',
    );
  }

  Future<void> _deleteFolderForever(FolderItem folder) async {
    final ok = await _showConfirm(
      'Delete folder "${folder.name}" forever? This cannot be undone.',
      confirmLabel: 'Delete Forever',
      destructive: true,
    );
    if (ok != true) return;

    await _runBusyAction(
      action: () => _api.purgeFolder(folder.id),
      successMessage: 'Folder deleted forever.',
    );
  }

  Future<void> _deleteFileForever(FileItem file) async {
    final ok = await _showConfirm(
      'Delete file "${file.name}" forever? This cannot be undone.',
      confirmLabel: 'Delete Forever',
      destructive: true,
    );
    if (ok != true) return;

    await _runBusyAction(
      action: () => _api.purgeFile(file.id),
      successMessage: 'File deleted forever.',
    );
  }

  Future<void> _emptyTrash() async {
    if (_folders.isEmpty && _files.isEmpty) return;

    final ok = await _showConfirm(
      'Empty the recycle bin? All deleted items will be removed permanently.',
      confirmLabel: 'Empty',
      destructive: true,
    );
    if (ok != true) return;

    await _runBusyAction(
      action: _api.emptyTrash,
      successMessage: 'Recycle bin emptied.',
    );
  }

  Future<void> _runBusyAction({
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool?> _showConfirm(
    String message, {
    required String confirmLabel,
    bool destructive = false,
  }) {
    final confirmStyle = destructive
        ? TextButton.styleFrom(foregroundColor: Colors.red)
        : null;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: confirmStyle,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(FileItem file) {
    if (file.isImage) return Icons.image;
    if (file.isPdf) return Icons.picture_as_pdf;
    if (file.isMarkdown) return Icons.description;
    return Icons.insert_drive_file;
  }

  Widget _buildFilePreview(FileItem file) {
    final imageUrl = _api.thumbnailUrl(file.id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        color: const Color(0xFFF2F4F7),
        child: Image.network(
          imageUrl,
          headers: _api.authHeaders,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          cacheWidth: 104,
          cacheHeight: 104,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) =>
              Icon(_fileIcon(file), size: 30, color: Colors.blueGrey),
        ),
      ),
    );
  }

  String _folderSubtitle(FolderItem folder) {
    final deletedAt = formatTimestamp(folder.deletedAt);
    return deletedAt.isEmpty ? 'Deleted item' : 'Deleted on $deletedAt';
  }

  String _fileSubtitle(FileItem file) {
    final deletedAt = formatTimestamp(file.deletedAt);
    if (deletedAt.isEmpty) {
      return file.sizeStr;
    }
    return '${file.sizeStr} - Deleted on $deletedAt';
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _folders.isNotEmpty || _files.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Empty Recycle Bin',
            onPressed: hasItems && !_busy ? _emptyTrash : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _refresh, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_folders.isNotEmpty) _buildSectionHeader('Folders'),
          ..._folders.map(_buildFolderTile),
          if (_files.isNotEmpty) _buildSectionHeader('Files'),
          ..._files.map(_buildFileTile),
          if (_folders.isEmpty && _files.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Recycle bin is empty.')),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildFolderTile(FolderItem folder) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber, size: 36),
      title: Text(folder.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(_folderSubtitle(folder)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'restore') {
            _restoreFolder(folder);
          } else if (value == 'delete_forever') {
            _deleteFolderForever(folder);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'restore', child: Text('Restore')),
          PopupMenuItem(value: 'delete_forever', child: Text('Delete Forever')),
        ],
      ),
    );
  }

  Widget _buildFileTile(FileItem file) {
    return ListTile(
      leading: _buildFilePreview(file),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(_fileSubtitle(file)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'restore') {
            _restoreFile(file);
          } else if (value == 'delete_forever') {
            _deleteFileForever(file);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'restore', child: Text('Restore')),
          PopupMenuItem(value: 'delete_forever', child: Text('Delete Forever')),
        ],
      ),
    );
  }
}
