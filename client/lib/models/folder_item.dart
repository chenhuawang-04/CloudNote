class FolderItem {
  final String id;
  final String name;
  final String? parentId;
  final String createdAt;
  final String updatedAt;

  FolderItem({
    required this.id,
    required this.name,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) {
    return FolderItem(
      id: json['id'],
      name: json['name'],
      parentId: json['parent_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
