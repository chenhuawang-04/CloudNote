import 'package:flutter/material.dart';
import '../models/folder_item.dart';

class FolderTile extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.folder, color: Colors.amber, size: 40),
      title: Text(folder.name),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'rename') onRename?.call();
          if (v == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'rename', child: Text('重命名')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
