import 'dart:async';

import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../models/folder_item.dart';
import '../services/api_client.dart';
import '../utils/browse_sort.dart';
import '../widgets/file_tile.dart';
import '../widgets/folder_tile.dart';
import 'file_preview_screen.dart';
import 'folder_screen.dart';
import 'ocr_submit_screen.dart';
import 'ocr_tasks_screen.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import 'upload_screen.dart';

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
  bool _selectionMode = false;
  bool _deleting = false;
  String? _error;
  BrowseSortMode _sortMode = BrowseSortMode.name;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedFolderIds = {};
  final Set<String> _selectedFileIds = {};
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  int get _selectedCount => _selectedFolderIds.length + _selectedFileIds.length;

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = _searchQuery.isEmpty
          ? await _api.browse()
          : await _api.search(_searchQuery);
      final folders = (data['folders'] as List)
          .map((json) => FolderItem.fromJson(json))
          .toList();
      final files = (data['files'] as List)
          .map((json) => FileItem.fromJson(json))
          .toList();
      _sortItems(folders: folders, files: files);
      setState(() {
        _folders = folders;
        _files = files;
        _syncSelectionWithVisibleItems();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Load failed: $e';
        _loading = false;
      });
    }
  }

  void _sortItems({
    required List<FolderItem> folders,
    required List<FileItem> files,
  }) {
    folders.sort((a, b) => compareFolders(a, b, _sortMode));
    files.sort((a, b) => compareFiles(a, b, _sortMode));
  }

  void _setSortMode(BrowseSortMode? mode) {
    if (mode == null || mode == _sortMode) return;
    setState(() {
      _sortMode = mode;
      _sortItems(folders: _folders, files: _files);
    });
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final query = value.trim();
      if (query == _searchQuery) return;
      setState(() {
        _searchQuery = query;
      });
      _refresh();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_searchController.text.isEmpty && _searchQuery.isEmpty) return;
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
    _refresh();
  }

  void _syncSelectionWithVisibleItems() {
    final visibleFolderIds = _folders.map((folder) => folder.id).toSet();
    final visibleFileIds = _files.map((file) => file.id).toSet();
    _selectedFolderIds.removeWhere((id) => !visibleFolderIds.contains(id));
    _selectedFileIds.removeWhere((id) => !visibleFileIds.contains(id));
    if (_selectedCount == 0) {
      _selectionMode = false;
    }
  }

  Future<void> _createFolder() async {
    final name = await _showInputDialog(
      title: 'New Folder',
      hint: 'Folder name',
    );
    if (name == null || name.isEmpty) return;
    try {
      await _api.createFolder(name);
      await _refresh();
    } catch (e) {
      _showError('Create failed: $e');
    }
  }

  Future<void> _renameFolder(FolderItem folder) async {
    final name = await _showInputDialog(
      title: 'Rename Folder',
      hint: 'Folder name',
      initial: folder.name,
    );
    if (name == null || name.isEmpty) return;
    try {
      await _api.renameFolder(folder.id, name);
      await _refresh();
    } catch (e) {
      _showError('Rename failed: $e');
    }
  }

  Future<void> _deleteFolder(FolderItem folder) async {
    final ok = await _showConfirm(
      'Delete folder "${folder.name}" and all of its contents?',
    );
    if (ok != true) return;
    try {
      await _api.deleteFolder(folder.id);
      await _refresh();
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    final ok = await _showConfirm('Delete file "${file.name}"?');
    if (ok != true) return;
    try {
      await _api.deleteFile(file.id);
      await _refresh();
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  void _enterSelectionMode({String? folderId, String? fileId}) {
    setState(() {
      _selectionMode = true;
      if (folderId != null) _selectedFolderIds.add(folderId);
      if (fileId != null) _selectedFileIds.add(fileId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedFolderIds.clear();
      _selectedFileIds.clear();
    });
  }

  void _toggleFolderSelection(String folderId, bool selected) {
    setState(() {
      if (selected) {
        _selectedFolderIds.add(folderId);
      } else {
        _selectedFolderIds.remove(folderId);
      }
      if (_selectedCount == 0) {
        _selectionMode = false;
      }
    });
  }

  void _toggleFileSelection(String fileId, bool selected) {
    setState(() {
      if (selected) {
        _selectedFileIds.add(fileId);
      } else {
        _selectedFileIds.remove(fileId);
      }
      if (_selectedCount == 0) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final folders = _folders
        .where((folder) => _selectedFolderIds.contains(folder.id))
        .toList();
    final files = _files
        .where((file) => _selectedFileIds.contains(file.id))
        .toList();
    if (folders.isEmpty && files.isEmpty) return;
    await _deleteTargets(
      folders: folders,
      files: files,
      message:
          'Delete $_selectedCount selected item(s)? Folder contents will also be deleted.',
    );
  }

  Future<void> _clearAll() async {
    if (_folders.isEmpty && _files.isEmpty) return;
    await _deleteTargets(
      folders: _folders,
      files: _files,
      message:
          'Clear everything in the root list? This will delete all files and folders shown here.',
    );
  }

  Future<void> _deleteTargets({
    required List<FolderItem> folders,
    required List<FileItem> files,
    required String message,
  }) async {
    final ok = await _showConfirm(message);
    if (ok != true) return;

    setState(() => _deleting = true);
    var deleted = 0;
    final failures = <String>[];

    try {
      for (final file in files) {
        try {
          await _api.deleteFile(file.id);
          deleted += 1;
        } catch (e) {
          failures.add('File ${file.name}: $e');
        }
      }

      for (final folder in folders) {
        try {
          await _api.deleteFolder(folder.id);
          deleted += 1;
        } catch (e) {
          failures.add('Folder ${folder.name}: $e');
        }
      }

      _exitSelectionMode();
      await _refresh();
      if (!mounted) return;

      if (failures.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Deleted $deleted item(s).')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Deleted $deleted item(s), ${failures.length} failed.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  Future<String?> _showInputDialog({
    required String title,
    required String hint,
    String? initial,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirm(String message) {
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
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode ? '$_selectedCount selected' : 'CloudNote'),
        actions: _selectionMode
            ? _buildSelectionActions()
            : _buildMainActions(),
      ),
      floatingActionButton: _selectionMode
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'folder',
                  onPressed: _deleting ? null : _createFolder,
                  child: const Icon(Icons.create_new_folder),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'upload',
                  onPressed: _deleting
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UploadScreen(),
                          ),
                        ).then((_) => _refresh()),
                  child: const Icon(Icons.upload_file),
                ),
              ],
            ),
      body: Stack(
        children: [
          _buildBody(),
          if (_deleting)
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

  List<Widget> _buildMainActions() {
    final hasItems = _folders.isNotEmpty || _files.isNotEmpty;
    return [
      IconButton(
        icon: const Icon(Icons.delete_sweep),
        tooltip: 'Clear All',
        onPressed: hasItems && !_deleting && _searchQuery.isEmpty
            ? _clearAll
            : null,
      ),
      IconButton(
        icon: const Icon(Icons.checklist),
        tooltip: 'Select',
        onPressed: hasItems && !_deleting ? () => _enterSelectionMode() : null,
      ),
      IconButton(
        icon: const Icon(Icons.camera_alt),
        tooltip: 'OCR',
        onPressed: _deleting
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrSubmitScreen()),
              ).then((_) => _refresh()),
      ),
      IconButton(
        icon: const Icon(Icons.list_alt),
        tooltip: 'Tasks',
        onPressed: _deleting
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OcrTasksScreen()),
              ),
      ),
      IconButton(
        icon: const Icon(Icons.restore_from_trash),
        tooltip: 'Recycle Bin',
        onPressed: _deleting
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrashScreen()),
              ).then((_) => _refresh()),
      ),
      IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Settings',
        onPressed: _deleting
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
      ),
    ];
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: const Icon(Icons.delete),
        tooltip: 'Delete Selected',
        onPressed: _selectedCount > 0 && !_deleting ? _deleteSelected : null,
      ),
      IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel Selection',
        onPressed: _deleting ? null : _exitSelectionMode,
      ),
    ];
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
          _buildSearchBar(),
          _buildSortBar(),
          ..._folders.map(
            (folder) => FolderTile(
              folder: folder,
              selectable: _selectionMode,
              selected: _selectedFolderIds.contains(folder.id),
              onSelected: (selected) =>
                  _toggleFolderSelection(folder.id, selected),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
              ).then((_) => _refresh()),
              onLongPress: () => _enterSelectionMode(folderId: folder.id),
              onRename: () => _renameFolder(folder),
              onDelete: () => _deleteFolder(folder),
            ),
          ),
          ..._files.map(
            (file) => FileTile(
              file: file,
              selectable: _selectionMode,
              selected: _selectedFileIds.contains(file.id),
              onSelected: (selected) => _toggleFileSelection(file.id, selected),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FilePreviewScreen(file: file),
                ),
              ),
              onLongPress: () => _enterSelectionMode(fileId: file.id),
              onDownload: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FilePreviewScreen(file: file),
                ),
              ),
              onDelete: () => _deleteFile(file),
            ),
          ),
          if (_folders.isEmpty && _files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _searchQuery.isEmpty
                      ? 'Empty. Upload files or create a folder.'
                      : 'No results for "$_searchQuery".',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search files and folders',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty && _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearSearch,
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18),
          const SizedBox(width: 8),
          const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          DropdownButtonHideUnderline(
            child: DropdownButton<BrowseSortMode>(
              value: _sortMode,
              onChanged: _deleting ? null : _setSortMode,
              items: BrowseSortMode.values
                  .map(
                    (mode) => DropdownMenuItem<BrowseSortMode>(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
