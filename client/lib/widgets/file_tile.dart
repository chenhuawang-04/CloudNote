import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../services/api_client.dart';

class FileTile extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const FileTile({
    super.key,
    required this.file,
    this.onTap,
    this.onLongPress,
    this.onDownload,
    this.onDelete,
    this.selectable = false,
    this.selected = false,
    this.onSelected,
  });

  IconData get _icon {
    if (file.isImage) return Icons.image;
    if (file.isPdf) return Icons.picture_as_pdf;
    if (file.isMarkdown) return Icons.description;
    return Icons.insert_drive_file;
  }

  Widget _buildPreview() {
    final imageUrl = ApiClient().thumbnailUrl(file.id);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 56,
        height: 56,
        color: const Color(0xFFF2F4F7),
        child: Image.network(
          imageUrl,
          headers: ApiClient().authHeaders,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          cacheWidth: 112,
          cacheHeight: 112,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
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
              Icon(_icon, size: 28, color: Colors.blueGrey),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> get _menuItems {
    final items = <PopupMenuEntry<String>>[];
    if (onDownload != null) {
      items.add(
        const PopupMenuItem(value: 'download', child: Text('Download')),
      );
    }
    if (onDelete != null) {
      items.add(
        const PopupMenuItem(value: 'delete', child: Text('Move to Trash')),
      );
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
          : _buildPreview(),
      selected: selected,
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(file.sizeStr),
      onTap: selectable ? () => onSelected?.call(!selected) : onTap,
      onLongPress: onLongPress,
      trailing: selectable || menuItems.isEmpty
          ? null
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'download') onDownload?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => menuItems,
            ),
    );
  }
}
