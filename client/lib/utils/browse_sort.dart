import '../models/file_item.dart';
import '../models/folder_item.dart';

enum BrowseSortMode { name, newest, oldest }

extension BrowseSortModeLabel on BrowseSortMode {
  String get label {
    switch (this) {
      case BrowseSortMode.name:
        return 'Name';
      case BrowseSortMode.newest:
        return 'Newest';
      case BrowseSortMode.oldest:
        return 'Oldest';
    }
  }
}

DateTime _parseTimestamp(String value) {
  return DateTime.tryParse(value)?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

int compareFolders(FolderItem a, FolderItem b, BrowseSortMode mode) {
  switch (mode) {
    case BrowseSortMode.name:
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case BrowseSortMode.newest:
      final result = _parseTimestamp(
        b.createdAt,
      ).compareTo(_parseTimestamp(a.createdAt));
      return result != 0
          ? result
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case BrowseSortMode.oldest:
      final result = _parseTimestamp(
        a.createdAt,
      ).compareTo(_parseTimestamp(b.createdAt));
      return result != 0
          ? result
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

int compareFiles(FileItem a, FileItem b, BrowseSortMode mode) {
  switch (mode) {
    case BrowseSortMode.name:
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case BrowseSortMode.newest:
      final result = _parseTimestamp(
        b.createdAt,
      ).compareTo(_parseTimestamp(a.createdAt));
      return result != 0
          ? result
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case BrowseSortMode.oldest:
      final result = _parseTimestamp(
        a.createdAt,
      ).compareTo(_parseTimestamp(b.createdAt));
      return result != 0
          ? result
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}
