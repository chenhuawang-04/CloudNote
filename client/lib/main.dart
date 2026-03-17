import 'dart:io';

import 'package:flutter/material.dart';

import 'config.dart';
import 'screens/home_screen.dart';
import 'services/desktop_integration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const CloudNoteApp());
  if (Platform.isWindows) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DesktopIntegration.instance.init();
    });
  }
}

class CloudNoteApp extends StatelessWidget {
  const CloudNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}
