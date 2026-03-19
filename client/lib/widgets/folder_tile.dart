import 'package:flutter/material.dart';

import '../models/folder_item.dart';

class FolderTile extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const FolderTile({
    super.key,
    required this.folder,
    required this.onTap,
    this.onLongPress,
    this.onRename,
    this.onDelete,
    this.selectable = false,
    this.selected = false,
    this.onSelected,
  });

  List<PopupMenuEntry<String>> get _menuItems {
    final items = <PopupMenuEntry<String>>[];
    if (onRename != null) {
      items.add(const PopupMenuItem(value: 'rename', child: Text('Rename')));
    }
    if (onDelete != null) {
      items.add(const PopupMenuItem(
        value: 'delete',
        child: Text('Move to Trash'),
      ));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _menuItems;

    return ListTile(
      leading: selectable
          ? Checkbox(
              value: selected,
              onChanged: (value) => onSelected?.call(value ?? false),
            )
          : const Icon(Icons.folder, color: Colors.amber, size: 40),
      selected: selected,
      title: Text(folder.name),
      onTap: selectable ? () => onSelected?.call(!selected) : onTap,
      onLongPress: onLongPress,
      trailing: selectable || menuItems.isEmpty
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') onRename?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => menuItems,
            ),
    );
  }
}
