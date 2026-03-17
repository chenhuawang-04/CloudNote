import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'screenshot_watcher.dart';

class DesktopIntegration with TrayListener, WindowListener {
  DesktopIntegration._();

  static final DesktopIntegration instance = DesktopIntegration._();

  bool _initialized = false;
  bool _exiting = false;
  String? _iconPath;

  Future<void> init() async {
    if (_initialized || !Platform.isWindows) {
      return;
    }
    _initialized = true;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    await localNotifier.setup(appName: 'CloudNote');

    _iconPath = await _ensureTrayIcon();
    trayManager.addListener(this);
    await trayManager.setIcon(_iconPath!);
    await trayManager.setToolTip('CloudNote');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show'),
      MenuItem.separator(),
      MenuItem(key: 'exit', label: 'Exit'),
    ]));

    await ScreenshotWatcher.instance.start(iconPath: _iconPath);
  }

  Future<String> _ensureTrayIcon() async {
    final dir = await getApplicationSupportDirectory();
    final file = File(_joinPath(dir.path, 'tray_icon.ico'));
    if (!await file.exists()) {
      final data = await rootBundle.load('assets/tray_icon.ico');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    }
    return file.path;
  }

  String _joinPath(String base, String name) {
    final sep = Platform.pathSeparator;
    return base.endsWith(sep) ? '$base$name' : '$base$sep$name';
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitApp() async {
    _exiting = true;
    await ScreenshotWatcher.instance.stop();
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'exit':
        _exitApp();
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (_exiting) {
      return;
    }
    await windowManager.setPreventClose(true);
    await windowManager.hide();
  }
}
