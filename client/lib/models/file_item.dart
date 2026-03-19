class FileItem {
  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final String? folderId;
  final String createdAt;
  final String? deletedAt;

  FileItem({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    this.folderId,
    required this.createdAt,
    this.deletedAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['id'],
      name: json['name'],
      size: json['size'],
      mimeType: json['mime_type'],
      folderId: json['folder_id'],
      createdAt: json['created_at'],
      deletedAt: json['deleted_at'],
    );
  }

  String get sizeStr {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  bool get isImage =>
      mimeType != null && mimeType!.startsWith('image/');

  bool get isMarkdown {
    final lower = name.toLowerCase();
    if (lower.endsWith('.md') || lower.endsWith('.markdown')) return true;
    return mimeType != null &&
        (mimeType!.contains('markdown') || mimeType == 'text/plain');
  }

  bool get isPdf {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return true;
    return mimeType != null && mimeType == 'application/pdf';
  }
}
