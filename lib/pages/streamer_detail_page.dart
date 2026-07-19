import 'package:flutter/material.dart';
import '../models/streamer.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';

class StreamerDetailPage extends StatefulWidget {
  final ApiService api;
  final Streamer streamer;
  const StreamerDetailPage({super.key, required this.api, required this.streamer});

  @override
  State<StreamerDetailPage> createState() => _StreamerDetailPageState();
}

class _StreamerDetailPageState extends State<StreamerDetailPage> {
  bool _loading = true;
  Map<String, dynamic>? _detail;
  FileListResponse? _files;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _mapPlatform(String p) {
    switch (p) {
      case 'DouYin': return '抖音';
      case 'Bilibili': return 'B站';
      case 'DouYu': return '斗鱼';
      case 'Huya': return '虎牙';
      case 'KS':
      case 'Kuaishou': return '快手';
      default: return p.length > 2 ? p.substring(0, 2) : p;
    }
  }

  String _platDir(String p) {
    switch (p) {
      case 'DouYin': return '抖音';
      case 'Bilibili': return 'Bilibili';
      case 'DouYu': return '斗鱼';
      case 'Huya': return '虎牙';
      case 'KS':
      case 'Kuaishou': return '快手';
      default: return p;
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await widget.api.getStreamerDetail(widget.streamer.id);
      if (mounted) setState(() => _detail = d);
      // 录制目录：/app/video/平台/备注
      final path = '/app/video/${_platDir(widget.streamer.providerId)}/${widget.streamer.remarks.isNotEmpty ? widget.streamer.remarks : widget.streamer.name}';
      try {
        final f = await widget.api.getFileList(path);
        if (mounted) setState(() => _files = f);
      } catch (_) {
        if (mounted) setState(() => _files = null);
      }
    } catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.streamer;
    final plat = _mapPlatform(s.providerId);
    final statusLabel = s.isRecording ? '录制中' : (s.liveStatus ? '直播中' : '未开播');
    final statusColor = s.isRecording ? Colors.green : (s.liveStatus ? Colors.red : Colors.grey);

    // 文件统计
    int fileCount = 0;
    int totalSize = 0;
    int latest = 0;
    final recent = <String>[];
    if (_files != null) {
      for (final f in _files!.list) {
        if (!f.isDir) {
          fileCount++;
          totalSize += f.size;
          if (f.mtimeMs > latest) latest = f.mtimeMs;
          if (recent.length < 8) {
            recent.add('• ${f.name} (${_fmtSize(f.size)})');
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.name} - $plat'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // 头部
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  if (s.avatar != null && s.avatar!.isNotEmpty)
                    CircleAvatar(radius: 24, backgroundImage: NetworkImage(s.avatar!))
                  else
                    const CircleAvatar(radius: 24, child: Icon(Icons.person, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.pink, borderRadius: BorderRadius.circular(11)),
                          child: Text(plat, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(11)),
                          child: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                      ]),
                    ]),
                  ),
                ]),
                const Divider(height: 24),

                // 配置
                const Text('基础配置', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                _row('房间号', s.channelId),
                if (_detail != null) ...[
                  _row('画质', _detail!['quality']?.toString() ?? '-'),
                  _row('分段', '${_detail!['segment']?.toString() ?? '-'} 秒'),
                  _row('录制引擎', _detail!['recorderType']?.toString() ?? '-'),
                  _row('视频格式', '${_detail!['videoFormat']?.toString() ?? '-'} / ${_detail!['formatName']?.toString() ?? '-'}'),
                  _row('状态', _detail!['state']?.toString() ?? '-'),
                  _row('自动检查', (_detail!['disableAutoCheck'] as bool? ?? false) ? '禁用' : '开启'),
                ] else if (_err != null)
                  _row('配置', '加载失败: $_err'),

                const SizedBox(height: 16),
                const Text('录制文件', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                Text(
                  '文件: $fileCount 个 | 总大小: ${_fmtSize(totalSize)}'
                  '${latest > 0 ? ' | 最近: ${_fmtDate(latest)}' : ''}',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                ),
                if (fileCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(recent.join('\n'), style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.3)),
                  if (fileCount > recent.length)
                    Text('… 另有 ${fileCount - recent.length} 个', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ] else
                  const Text('暂无录制文件', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 72, child: Text(k, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, color: Color(0xFF333333)))),
        ]),
      );

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _fmtDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
