import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlCtrl;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: AppConfig.serverUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppConfig.setServerUrl(_urlCtrl.text.trim());
    setState(() => _status = '已保存');
  }

  Future<void> _test() async {
    setState(() => _status = '正在连接...');
    await AppConfig.setServerUrl(_urlCtrl.text.trim());
    final ok = await ApiClient().checkHealth();
    setState(() => _status = ok ? '连接成功' : '连接失败');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('服务器地址', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                hintText: 'http://192.168.1.100:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(onPressed: _save, child: const Text('保存')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _test, child: const Text('测试连接')),
                const SizedBox(width: 12),
                Text(_status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
