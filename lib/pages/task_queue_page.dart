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
      case 'error':
        return Colors.red;
      case 'canceled':
        return Colors.grey;
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
      case 'error':
        return '失败';
      case 'canceled':
        return '已取消';
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
      case 'ffmpeg':
        return '压制/合并';
      case 'biliUpload':
        return '上传B站';
      case 'bili':
        return '投稿B站';
      default:
        return t.isEmpty ? '任务' : t;
    }
  }

  /// 格式化完整日期时间
  String _fmtFullTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  /// 格式化简短时间（月日 时:分）
  String _fmtShortTime(int ms) {
    if (ms <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化时长（秒 → 可读字符串）
  String _fmtDur(int sec) {
    if (sec <= 0) return '';
    if (sec < 60) return '${sec}秒';
    final m = (sec / 60).floor();
    final s = sec % 60;
    if (m < 60) return '${m}分${s > 0 ? '$s秒' : ''}';
    final h = (m / 60).floor();
    final rm = m % 60;
    if (h < 24) return '${h}时${rm > 0 ? '${rm}分' : ''}';
    final d = (h / 24).floor();
    final rh = h % 24;
    return '${d}天${rh > 0 ? '${rh}时' : ''}';
  }

  /// 计算预计剩余时间（基于当前进度和已耗时）
  String? _estimateRemaining(double progress, int durationSec) {
    if (progress <= 0 || durationSec <= 0) return null;
    final remainingSec = (durationSec / progress) * (100 - progress);
    if (remainingSec < 0) return null;
    return _fmtDur(remainingSec.floor());
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
                        itemBuilder: (_, i) => _TaskCard(task: _list[i], fmtFullTime: _fmtFullTime, fmtShortTime: _fmtShortTime, fmtDur: _fmtDur, estimateRemaining: _estimateRemaining, statusColor: _statusColor, statusLabel: _statusLabel, typeLabel: _typeLabel),
                      ),
                    ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final String Function(int) fmtFullTime;
  final String Function(int) fmtShortTime;
  final String Function(int) fmtDur;
  final String? Function(double, int) estimateRemaining;
  final Color Function(String) statusColor;
  final String Function(String) statusLabel;
  final String Function(String) typeLabel;

  const _TaskCard({
    required this.task,
    required this.fmtFullTime,
    required this.fmtShortTime,
    required this.fmtDur,
    required this.estimateRemaining,
    required this.statusColor,
    required this.statusLabel,
    required this.typeLabel,
  });

  double get _progress {
    final v = task['progress'];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int get _duration => int.tryParse(task['duration']?.toString() ?? '0') ?? 0;
  int get _startTime => int.tryParse(task['startTime']?.toString() ?? '0') ?? 0;
  int get _endTime => int.tryParse(task['endTime']?.toString() ?? '0') ?? 0;
  String get status => task['status']?.toString() ?? '';
  String get name => task['name']?.toString() ?? '';
  String get type => task['type']?.toString() ?? '';
  String get errMsg => task['error']?.toString() ?? '';
  String get progressMsg => task['custsomProgressMsg']?.toString() ?? '';

  bool get _isRunning => status == 'running';

  @override
  Widget build(BuildContext context) {
    // 预计剩余时间（仅进行中且有进度/时长时才有值）
    final rem = _isRunning ? estimateRemaining(_progress, _duration) : null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 第一行：状态徽标 + 类型 + 时间
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor(status),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(statusLabel(status),
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(typeLabel(type),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF333333))),
            ),
            const Spacer(),
            Text(fmtShortTime(_startTime),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),

          // 任务名
          const SizedBox(height: 6),
          Text(name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),

          // 进度条区域（进行中或已完成有进度时显示）
          if (_isRunning || _progress > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress.clamp(0.0, 100.0) / 100,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 4),

            // 进度详情行：百分比 + 耗时 + 剩余 + 速度
            Row(children: [
              Text('${_progress.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 11, color: _isRunning ? Colors.blue : Colors.grey, fontWeight: FontWeight.w600)),
              if (_duration > 0) ...[
                const Text(' · ', style: TextStyle(color: Colors.grey)),
                Text('耗时 ${fmtDur(_duration)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
              if (rem != null) ...[
                const Text(' · ', style: TextStyle(color: Colors.grey)),
                Text('剩余约 $rem', style: const TextStyle(fontSize: 11, color: Colors.orange)),
              ],
            ]),
            // 速度/详细信息（如比特率、速率）
            if (progressMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(progressMsg,
                    style: const TextStyle(fontSize: 10, color: Colors.teal)),
              ),
          ],

          // 非进行中但有时长的任务
          if (!_isRunning && _progress <= 0 && _duration > 0) ...[
            const SizedBox(height: 4),
            Text('耗时 ${fmtDur(_duration)}'
                '${_endTime > 0 ? ' · ${fmtShortTime(_startTime)} ~ ${fmtShortTime(_endTime)}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],

          // 错误信息
          if (errMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('错误：$errMsg',
                  style: const TextStyle(fontSize: 11, color: Colors.red)),
            ),

          // 开始时间（完整格式，折叠查看）
          if (_startTime > 0) ...[
            const SizedBox(height: 4),
            Text('开始时间: ${fmtFullTime(_startTime)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ]),
      ),
    );
  }
}
