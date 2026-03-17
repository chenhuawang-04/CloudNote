import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileTile extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const FileTile({
    super.key,
    required this.file,
    this.onTap,
    this.onDownload,
    this.onDelete,
  });

  IconData get _icon {
    final mime = file.mimeType ?? '';
    if (mime.startsWith('image/')) return Icons.image;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    if (mime.startsWith('text/')) return Icons.description;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_icon, size: 36, color: Colors.blueGrey),
      title: Text(file.name, overflow: TextOverflow.ellipsis),
      subtitle: Text(file.sizeStr),
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'download') onDownload?.call();
          if (v == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'download', child: Text('下载')),
          const PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    );
  }
}
