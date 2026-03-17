import '../models/file_item.dart';
import 'api_client.dart';

class FileService {
  final _api = ApiClient();

  Future<List<FileItem>> list({String? folderId}) async {
    final data = await _api.listFiles(folderId: folderId);
    return data.map((j) => FileItem.fromJson(j)).toList();
  }

  Future<FileItem> upload(
    String filePath,
    String fileName, {
    String? folderId,
    void Function(int, int)? onProgress,
  }) async {
    final data = await _api.uploadFile(filePath, fileName,
        folderId: folderId, onProgress: onProgress);
    return FileItem.fromJson(data);
  }

  Future<void> download(String fileId, String savePath,
      {void Function(int, int)? onProgress}) async {
    await _api.downloadFile(fileId, savePath, onProgress: onProgress);
  }

  Future<void> delete(String id) async {
    await _api.deleteFile(id);
  }

  String downloadUrl(String fileId) => _api.downloadUrl(fileId);
}
