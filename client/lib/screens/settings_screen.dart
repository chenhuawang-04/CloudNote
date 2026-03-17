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
  late TextEditingController _aiBaseUrlCtrl;
  late TextEditingController _aiKeyCtrl;
  late TextEditingController _aiModelCtrl;
  String _status = '';
  String _aiStatus = '';
  bool _loadingAi = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: AppConfig.serverUrl);
    _aiBaseUrlCtrl = TextEditingController();
    _aiKeyCtrl = TextEditingController();
    _aiModelCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _aiBaseUrlCtrl.dispose();
    _aiKeyCtrl.dispose();
    _aiModelCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await AppConfig.setServerUrl(_urlCtrl.text.trim());
    setState(() => _status = '已保存');
    _loadAiSettings();
  }

  Future<void> _test() async {
    setState(() => _status = '正在连接...');
    await AppConfig.setServerUrl(_urlCtrl.text.trim());
    final ok = await ApiClient().checkHealth();
    setState(() => _status = ok ? '连接成功' : '连接失败');
    if (ok) _loadAiSettings();
  }

  Future<void> _loadAiSettings() async {
    setState(() => _loadingAi = true);
    try {
      final api = ApiClient();
      final res = await api.dio.get('${AppConfig.apiBase}/settings/ai');
      final data = res.data;
      setState(() {
        _aiBaseUrlCtrl.text = data['base_url'] ?? '';
        _aiModelCtrl.text = data['model'] ?? '';
        _aiKeyCtrl.text = '';
        _aiStatus = data['api_key_set'] == true
            ? 'API Key 已设置 (${data['api_key_preview']})'
            : 'API Key 未设置';
        _loadingAi = false;
      });
    } catch (e) {
      setState(() {
        _aiStatus = '加载AI设置失败';
        _loadingAi = false;
      });
    }
  }

  Future<void> _saveAiSettings() async {
    setState(() => _aiStatus = '正在保存...');
    try {
      final api = ApiClient();
      final body = <String, dynamic>{};
      if (_aiBaseUrlCtrl.text.trim().isNotEmpty) {
        body['base_url'] = _aiBaseUrlCtrl.text.trim();
      }
      if (_aiKeyCtrl.text.trim().isNotEmpty) {
        body['api_key'] = _aiKeyCtrl.text.trim();
      }
      if (_aiModelCtrl.text.trim().isNotEmpty) {
        body['model'] = _aiModelCtrl.text.trim();
      }
      final res = await api.dio.put('${AppConfig.apiBase}/settings/ai', data: body);
      final data = res.data;
      setState(() {
        _aiKeyCtrl.text = '';
        _aiStatus = data['api_key_set'] == true
            ? '已保存 - API Key (${data['api_key_preview']})'
            : '已保存 - API Key 未设置';
      });
    } catch (e) {
      setState(() => _aiStatus = '保存失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Server Connection ──
            const Text('服务器连接',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://192.168.1.100:8000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(onPressed: _save, child: const Text('保存')),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: _test, child: const Text('测试连接')),
                const SizedBox(width: 12),
                Flexible(child: Text(_status, overflow: TextOverflow.ellipsis)),
              ],
            ),

            const Divider(height: 32),

            // ── AI Settings ──
            Row(
              children: [
                const Text('AI 设置',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                if (_loadingAi)
                  const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadAiSettings,
                    tooltip: '刷新',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _aiBaseUrlCtrl,
              decoration: const InputDecoration(
                labelText: 'AI Base URL',
                hintText: 'https://api.openai.com/v1',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiKeyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key (留空则不修改)',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _aiModelCtrl,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'gpt-4o',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                    onPressed: _saveAiSettings, child: const Text('保存AI设置')),
                const SizedBox(width: 12),
                Flexible(child: Text(_aiStatus, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
