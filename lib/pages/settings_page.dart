import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SettingsPage extends StatefulWidget {
  final ApiService api;
  const SettingsPage({super.key, required this.api});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _urlC = TextEditingController();
  final _passC = TextEditingController();
  String _status = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  void _restore() {
    if (widget.api.baseUrl.isNotEmpty) _urlC.text = widget.api.baseUrl;
  }

  Future<void> _save() async {
    var url = _urlC.text.trim();
    final pass = _passC.text.trim();
    if (url.isEmpty) {
      setState(() => _status = '请填写后台地址');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://' + url;
    }
    widget.api.setConfig(url, pass);
    setState(() => _status = '配置已保存，切到「主播」页即可使用');
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('配置已保存')));
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    _save();
    setState(() => _status = '测试连接中...');
    try {
      final msg = await widget.api.testConnection();
      setState(() => _status = msg);
    } catch (e) {
      setState(() => _status = '连接失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('连接设置',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlC,
            decoration: const InputDecoration(
              labelText: '后台地址',
              hintText: '如 http://1.2.3.4:50076',
              border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passC,
            decoration: const InputDecoration(
              labelText: 'Passkey（Authorization）',
              border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(
                onPressed: _testing ? null : _test,
                child: const Text('测试连接')),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _save, child: const Text('保存')),
          ]),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_status,
                  style: const TextStyle(fontSize: 13, color: Colors.blue)),
            ),
          const SizedBox(height: 16),
          const Text('关于',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            '本 App 直连你的 biliLive-tools 后台，地址与密码仅保存在本机，不会上传。',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
