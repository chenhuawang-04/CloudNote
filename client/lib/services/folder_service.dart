import '../models/folder_item.dart';
import 'api_client.dart';

class FolderService {
  final _api = ApiClient();

  Future<List<FolderItem>> list({String? parentId}) async {
    final data = await _api.listFolders(parentId: parentId);
    return data.map((j) => FolderItem.fromJson(j)).toList();
  }

  Future<FolderItem> create(String name, {String? parentId}) async {
    final data = await _api.createFolder(name, parentId: parentId);
    return FolderItem.fromJson(data);
  }

  Future<void> rename(String id, String name) async {
    await _api.renameFolder(id, name);
  }

  Future<void> delete(String id) async {
    await _api.deleteFolder(id);
  }
}
