import 'package:flutter/material.dart';
import '../models/streamer.dart';
import '../services/api_service.dart';
import 'streamer_detail_page.dart';

// 文件级共享方法：平台ID → 中文显示名
String mapPlatform(String p) {
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

class StreamerListPage extends StatefulWidget {
  final ApiService api;
  const StreamerListPage({super.key, required this.api});

  @override
  State<StreamerListPage> createState() => _StreamerListPageState();
}

class _StreamerListPageState extends State<StreamerListPage> {
  List<Streamer> _list = [];
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
      final data = await widget.api.getStreamerList();
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

  Future<void> _op(String label, Future<void> Function() fn) async {
    try {
      await fn();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label 已发送')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$label 失败: $e')));
      }
    }
  }

  void _confirmDelete(Streamer s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除「${s.name}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _op('删除', () => widget.api.deleteStreamer(s.id));
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMore(Streamer s, BuildContext anchor) async {
    final RenderBox box = anchor.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero) & box.size;
    final pick = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(pos, Offset.zero & (anchor.findRenderObject() as RenderObject).semanticBounds.size),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('编辑主播')),
        PopupMenuItem(value: 'delete', child: Text('删除主播', style: TextStyle(color: Colors.red))),
      ],
    );
    if (pick == 'edit') _showEdit(s);
    else if (pick == 'delete') _confirmDelete(s);
  }

  void _showEdit(Streamer s) {
    final nameC = TextEditingController(text: s.remarks);
    final platC = TextEditingController(text: s.providerId);
    final chC = TextEditingController(text: s.channelId);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('编辑主播'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameC, decoration: const InputDecoration(labelText: '备注名')),
          TextField(controller: platC, decoration: const InputDecoration(labelText: '平台(如 Bilibili/DouYin)')),
          TextField(controller: chC, decoration: const InputDecoration(labelText: '房间号/频道ID')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _op('保存', () => widget.api.updateStreamer(
                    s.id, platC.text.trim(), chC.text.trim(), nameC.text.trim()));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAdd() {
    final urlC = TextEditingController();
    final nameC = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('添加主播'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: urlC,
            decoration: const InputDecoration(
              labelText: '直播间地址',
              hintText: '粘贴如 https://live.douyin.com/xxxx',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameC,
            decoration: const InputDecoration(labelText: '备注名（可选）'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final url = urlC.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(context);
              _addByUrl(url, nameC.text.trim());
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  // 按直播间地址自动识别平台+频道（使用后台官方解析器）
  Future<void> _addByUrl(String url, String remarks) async {
    try {
      final r = await widget.api.resolveChannel(url);
      final platName = mapPlatform(r['providerId']!);
      await widget.api.addStreamer(
          r['providerId']!, r['channelId']!, remarks);
      if (mounted) {
        // 更明显的成功提示，包含平台信息
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ 已添加 $platName 主播${remarks.isNotEmpty ? "「$remarks」" : ""}'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ));
        // 稍微延迟刷新，让后端有时间填充头像等信息
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) _load();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加失败：$e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _openDetail(Streamer s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StreamerDetailPage(api: widget.api, streamer: s)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('主播'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _showAdd),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text('加载失败: $_err\n请检查设置中的地址和密码'))
              : _list.isEmpty
                  ? const Center(child: Text('暂无主播，点右上角 + 添加'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => _StreamerCard(
                          s: _list[i],
                          api: widget.api,
                          onDetail: _openDetail,
                          onEdit: _showEdit,
                          onDelete: _confirmDelete,
                          onCheck: () => _op('刷新', () => widget.api.checkStreamer(_list[i].id)),
                          onStart: () => _op('开始录制', () => widget.api.startRecord(_list[i].id)),
                          onStop: () => _op('停止录制', () => widget.api.stopRecord(_list[i].id)),
                          onMore: (ctx) => _showMore(_list[i], ctx),
                        ),
                      ),
                    ),
    );
  }
}

class _StreamerCard extends StatelessWidget {
  final Streamer s;
  final ApiService api;
  final void Function(Streamer) onDetail;
  final void Function(Streamer) onEdit;
  final void Function(Streamer) onDelete;
  final void Function() onCheck;
  final void Function() onStart;
  final void Function() onStop;
  final void Function(BuildContext) onMore;

  const _StreamerCard({
    super.key,
    required this.s,
    required this.api,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onCheck,
    required this.onStart,
    required this.onStop,
    required this.onMore,
  });

  String get _statusLabel {
    if (s.isRecording) return '录制中';
    if (s.liveStatus) return '直播中';
    return '未开播';
  }

  Color get _statusColor {
    if (s.isRecording) return Colors.green;
    if (s.liveStatus) return Colors.red;
    return Colors.grey;
  }

  Color _platformColor(String p) {
    switch (p) {
      case 'DouYin': return const Color(0xFFFE2C55);
      case 'Bilibili': return const Color(0xFFFB7299);
      case 'DouYu': return const Color(0xFFFF7700);
      case 'Huya': return const Color(0xFFFF5400);
      case 'KS':
      case 'Kuaishou': return const Color(0xFFFF4906);
      default: return const Color(0xFF607D8B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plat = mapPlatform(s.providerId);
    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 110, height: 80, color: const Color(0xFFEEEEEE),
              child: (s.cover != null && s.cover!.isNotEmpty)
                  ? Image.network(s.cover!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey))
                  : const Icon(Icons.image, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (s.liveTitle != null && s.liveTitle!.isNotEmpty) ...[
              Text(s.liveTitle!, style: const TextStyle(fontSize: 12, color: Color(0xFFFB7299))),
            ],
            if (s.lastRecordTime != null && s.lastRecordTime! > 0) ...[
              Text('上次录制: ${_ago(s.lastRecordTime!)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
            const SizedBox(height: 6),
            Row(children: [
              if (s.avatar != null && s.avatar!.isNotEmpty)
                CircleAvatar(radius: 15, backgroundImage: NetworkImage(s.avatar!))
              else
                const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.remarks.isNotEmpty ? s.remarks : (s.url ?? s.channelId),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _platformColor(s.providerId), borderRadius: BorderRadius.circular(11)),
                child: Text(plat, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(11)),
                child: Text(_statusLabel, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () => onMore(context)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: s.isRecording ? onStop : onStart,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: s.isRecording ? Colors.red : const Color(0xFFFB7299),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  child: Text(s.isRecording ? '停录' : '开录'),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCheck,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
                  child: const Text('刷新'),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onDetail(s),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  child: Text('详情', style: TextStyle(color: Color(0xFF2196F3), fontSize: 12)),
                ),
              ),
            ]),
          ])),
        ]),
      ),
    );
  }

  String _ago(int ms) {
    final sec = ((DateTime.now().millisecondsSinceEpoch - ms) / 1000).floor();
    if (sec < 60) return '刚刚';
    final min = (sec / 60).floor();
    if (min < 60) return '$min分钟前';
    final hr = (min / 60).floor();
    if (hr < 24) return '$hr小时前';
    final day = (hr / 24).floor();
    if (day < 30) return '$day天前';
    return '${(day / 30).floor()}个月前';
  }
}
