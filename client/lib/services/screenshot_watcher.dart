import 'dart:async';
import 'dart:io';

import 'package:local_notifier/local_notifier.dart';

import 'file_service.dart';

class ScreenshotWatcher {
  ScreenshotWatcher._();

  static final ScreenshotWatcher instance = ScreenshotWatcher._();

  StreamSubscription<FileSystemEvent>? _subscription;
  final Map<String, DateTime> _recent = {};
  String? _iconPath;

  Future<void> start({String? iconPath}) async {
    if (!Platform.isWindows || _subscription != null) {
      return;
    }
    _iconPath = iconPath;

    final dirPath = _defaultScreenshotDir();
    if (dirPath.isEmpty) {
      return;
    }
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    _subscription = directory.watch(
      events: FileSystemEvent.create | FileSystemEvent.modify,
    ).listen(_onEvent);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(FileSystemEvent event) {
    final path = event.path;
    if (!_isImage(path)) {
      return;
    }

    final now = DateTime.now();
    final last = _recent[path];
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }
    _recent[path] = now;
    _pruneRecent(now);

    unawaited(_promptUpload(path));
  }

  Future<void> _promptUpload(String path) async {
    if (!await _waitForStableFile(path)) {
      return;
    }
    final fileName = _basename(path);
    final notification = LocalNotification(
      title: 'New screenshot detected',
      body: '$fileName - click to upload',
      icon: _iconPath,
    );
    notification.onClick = () {
      unawaited(_upload(path));
    };
    await notification.show();
  }

  Future<void> _upload(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return;
    }
    final fileName = _basename(path);
    try {
      await FileService().upload(path, fileName);
      final success = LocalNotification(
        title: 'Upload complete',
        body: fileName,
        icon: _iconPath,
      );
      await success.show();
    } catch (e) {
      final failure = LocalNotification(
        title: 'Upload failed',
        body: '$fileName - $e',
        icon: _iconPath,
      );
      await failure.show();
    }
  }

  Future<bool> _waitForStableFile(String path) async {
    const maxAttempts = 15;
    const delay = Duration(milliseconds: 300);
    int? lastSize;
    int stableCount = 0;

    for (var i = 0; i < maxAttempts; i++) {
      try {
        final size = await File(path).length();
        if (size > 0 && size == lastSize) {
          stableCount += 1;
          if (stableCount >= 2) {
            return true;
          }
        } else {
          stableCount = 0;
        }
        lastSize = size;
      } catch (_) {
        stableCount = 0;
      }
      await Future.delayed(delay);
    }
    return false;
  }

  void _pruneRecent(DateTime now) {
    if (_recent.length < 200) {
      return;
    }
    _recent.removeWhere((_, time) => now.difference(time) > const Duration(minutes: 10));
  }

  String _basename(String path) {
    final sep = Platform.pathSeparator;
    final idx = path.lastIndexOf(sep);
    return idx == -1 ? path : path.substring(idx + 1);
  }

  bool _isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.gif');
  }

  String _defaultScreenshotDir() {
    if (!Platform.isWindows) {
      return '';
    }
    final home = Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      return '';
    }
    return '$home\\Pictures\\Screenshots';
  }
}
