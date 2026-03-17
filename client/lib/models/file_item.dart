class FileItem {
  final String id;
  final String name;
  final int size;
  final String? mimeType;
  final String? folderId;
  final String createdAt;

  FileItem({
    required this.id,
    required this.name,
    required this.size,
    this.mimeType,
    this.folderId,
    required this.createdAt,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      id: json['id'],
      name: json['name'],
      size: json['size'],
      mimeType: json['mime_type'],
      folderId: json['folder_id'],
      createdAt: json['created_at'],
    );
  }

  String get sizeStr {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  bool get isImage =>
      mimeType != null && mimeType!.startsWith('image/');
}
