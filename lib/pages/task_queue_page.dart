import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskQueuePage extends StatefulWidget {
  final ApiService api;
  const TaskQueuePage({super.key, required this.api});

  @override
  State<TaskQueuePage> createState() => _TaskQueuePageState();
}

class _TaskQueuePageState extends State<TaskQueuePage> {
  List<Map<String, dynamic>> _list = [];
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await widget.api.getTaskList();
      // 排序：进行中优先，其余按开始时间倒序
      data.sort((a, b) {
        final ar = (a['status']?.toString() ?? '') == 'running' ? 0 : 1;
        final br = (b['status']?.toString() ?? '') == 'running' ? 0 : 1;
        if (ar != br) return ar - br;
        final at = int.tryParse(a['startTime']?.toString() ?? '0') ?? 0;
        final bt = int.tryParse(b['startTime']?.toString() ?? '0') ?? 0;
        return bt - at;
      });
      setState(() {
        _list = data;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _err = e.toString();
      });
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'running':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'running':
        return '进行中';
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      case 'pending':
        return '排队中';
      default:
        return s.isEmpty ? '未知' : s;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'danmu':
        return '弹幕转换';
      case 'record':
        return '录制';
      default:
        return t.isEmpty ? '任务' : t;
    }
  }

  String _fmtTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDur(int sec) {
    if (sec <= 0) return '';
    final m = (sec / 60).floor();
    final s = sec % 60;
    if (m > 0) return '${m}分${s}秒';
    return '${s}秒';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务队列'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text('加载失败：$_err'))
              : _list.isEmpty
                  ? const Center(child: Text('暂无任务'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _list.length,
                        itemBuilder: (_, i) {
                          final t = _list[i];
                          final status = t['status']?.toString() ?? '';
                          final name = t['name']?.toString() ?? '';
                          final type = t['type']?.toString() ?? '';
                          final progress =
                              int.tryParse(t['progress']?.toString() ?? '0') ?? 0;
                          final dur =
                              int.tryParse(t['duration']?.toString() ?? '0') ?? 0;
                          final st =
                              int.tryParse(t['startTime']?.toString() ?? '0') ?? 0;
                          final et =
                              int.tryParse(t['endTime']?.toString() ?? '0') ?? 0;
                          final err = t['error']?.toString() ?? '';
                          return Card(
                            margin: const EdgeInsets.all(8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(_statusLabel(status),
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 11)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Text(_typeLabel(type),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF333333))),
                                    ),
                                    const Spacer(),
                                    Text(_fmtTime(st),
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(name,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6),
                                  if (status == 'running' || progress > 0) ...[
                                    LinearProgressIndicator(
                                        value: progress / 100, minHeight: 4),
                                    const SizedBox(height: 4),
                                    Text(
                                        dur > 0
                                            ? '进度 $progress% · 耗时 ${_fmtDur(dur)}'
                                            : '进度 $progress%',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ] else if (dur > 0) ...[
                                    Text(
                                        '耗时 ${_fmtDur(dur)} · '
                                        '${_fmtTime(st)}~${_fmtTime(et)}',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey)),
                                  ],
                                  if (err.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('错误：$err',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.red)),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
