import 'dart:async';
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

  // 看板
  String _uptime = '—';
  String _diskUsed = '—';
  String _diskFileCount = '0';
  bool _dashLoading = false;

  @override
  void initState() {
    super.initState();
    _restore();
    _loadDashboard();
  }

  void _restore() {
    // 从后端配置回显（此处简化：直接依赖 api 已 setConfig）
    if (widget.api.baseUrl.isNotEmpty) _urlC.text = widget.api.baseUrl;
  }

  Future<void> _save() async {
    var url = _urlC.text.trim();
    final pass = _passC.text.trim();
    if (url.isEmpty) {
      setState(() => _status = '请填写后台地址');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://' + url;
    widget.api.setConfig(url, pass);
    setState(() => _status = '配置已保存，切到「主播」页即可使用');
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('配置已保存')));
    _loadDashboard();
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    _save();
    setState(() => _status = '测试连接中...');
    try {
      final msg = await widget.api.testConnection();
      setState(() => _status = msg);
      _loadDashboard();
    } catch (e) {
      setState(() => _status = '连接失败: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  // ---- 看板 ----
  Future<void> _loadDashboard() async {
    if (!widget.api.configured) return;
    setState(() => _dashLoading = true);
    // 运行时间：startTime 后台返回字符串
    try {
      final raw = await widget.api.getStatistics();
      final startStr = raw['startTime']?.toString() ?? '0';
      final start = int.tryParse(startStr) ?? 0;
      final up = start > 0 ? DateTime.now().millisecondsSinceEpoch - start : 0;
      if (mounted) setState(() => _uptime = up > 0 ? _fmtUptime(up) : '未知');
    } catch (_) {
      if (mounted) setState(() => _uptime = '获取失败');
    }
    // 磁盘：递归扫 /app/video（最深2层）
    _scanDisk('/app/video', 0);
  }

  Future<void> _scanDisk(String path, int depth) async {
    if (depth > 2) {
      _finalizeDisk(0, 0);
      return;
    }
    try {
      final r = await widget.api.getFileList(path);
      var totalSize = 0;
      var fileCount = 0;
      final subDirs = <String>[];
      for (final f in r.list) {
        if (!f.isDir) {
          totalSize += f.size;
          fileCount++;
        } else if (depth < 2) {
          subDirs.add(f.path);
        }
      }
      if (subDirs.isEmpty || depth >= 2) {
        _finalizeDisk(totalSize, fileCount);
      } else {
        var accSize = totalSize;
        var accCount = fileCount;
        var done = 0;
        final total = subDirs.length;
        for (final d in subDirs) {
          try {
            final ir = await widget.api.getFileList(d);
            for (final f in ir.list) {
              if (!f.isDir) {
                accSize += f.size;
                accCount++;
              }
            }
          } catch (_) {}
          done++;
          if (done >= total) _finalizeDisk(accSize, accCount);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _diskUsed = '获取失败');
    }
  }

  void _finalizeDisk(int totalSize, int fileCount) {
    if (!mounted) return;
    setState(() {
      _diskUsed = _fmtSize(totalSize);
      _diskFileCount = fileCount.toString();
      _dashLoading = false;
    });
  }

  String _fmtUptime(int ms) {
    var s = (ms / 1000).floor();
    final d = (s / 86400);
    s %= 86400;
    final h = (s / 3600);
    s %= 3600;
    final m = (s / 60);
    if (d > 0) return '${d}天${h}时';
    if (h > 0) return '${h}时${m}分';
    return '${m}分';
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    var v = b.toDouble();
    const units = ['KB', 'MB', 'GB', 'TB'];
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('连接设置', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _urlC,
            decoration: const InputDecoration(
              labelText: '后台地址', hintText: '如 http://1.2.3.4:50076',
              border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _passC,
            decoration: const InputDecoration(
              labelText: 'Passkey（Authorization）', border: OutlineInputBorder()),
            obscureText: true,
          ),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton(onPressed: _testing ? null : _test, child: const Text('测试连接')),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _save, child: const Text('保存')),
          ]),
          if (_status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_status, style: const TextStyle(fontSize: 13, color: Colors.blue)),
            ),

          const Divider(height: 28),
          const Text('运行状态', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _statTile('运行时间', _dashLoading ? '加载中...' : _uptime),
          _statTile('录制目录已用', _dashLoading ? '加载中...' : _diskUsed),
          _statTile('录制文件数', _diskFileCount),
          const Text('（剩余/总计需后台磁盘接口，暂未提供）',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _statTile(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 14, color: Color(0xFF333333)))),
        ]),
      );
}
