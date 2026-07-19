import 'dart:async';
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
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // 静默自动刷新：每 5 秒拉一次，让"录制中"的画质/已录时长实时走秒
    _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  // silent=true 时不显示整页 loading，用于后台定时刷新，避免闪烁
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final data = await widget.api.getStreamerList();
      if (!mounted) return;
      setState(() {
        _list = data;
        _loading = false;
        _err = null;
      });
    } catch (e) {
      if (!mounted) return;
      // 静默刷新失败不打断界面（保留上次数据），仅首屏/手动刷新才报错
      if (!silent) {
        setState(() {
          _loading = false;
          _err = e.toString();
        });
      }
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
    final showRec = s.isRecording &&
        ((s.usedStream != null && s.usedStream!.isNotEmpty) ||
            (s.recordProgress != null && s.recordProgress!.isNotEmpty));
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      elevation: 2,
      shadowColor: const Color(0x1A000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 封面（加录制中角标）
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 96, height: 96, color: const Color(0xFFEEEEEE),
                child: (s.cover != null && s.cover!.isNotEmpty)
                    ? Image.network(s.cover!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Colors.grey))
                    : const Icon(Icons.image, color: Colors.grey),
              ),
            ),
            if (s.isRecording)
              Positioned(
                top: 6, left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red, borderRadius: BorderRadius.circular(6)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fiber_manual_record, size: 7, color: Colors.white),
                    SizedBox(width: 3),
                    Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 第一行：主播名（独占一行，不再被胶囊挤占）
            Text(s.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 3),
            // 录制中胶囊：画质 + 已录时长（独立一行，左对齐）
            if (showRec)
              Container(
                margin: const EdgeInsets.only(top: 2, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x14FB7299),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (s.usedStream != null && s.usedStream!.isNotEmpty)
                    Text(s.usedStream!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFFB7299), fontWeight: FontWeight.w600)),
                  if (s.recordProgress != null && s.recordProgress!.isNotEmpty) ...[
                    if (s.usedStream != null && s.usedStream!.isNotEmpty)
                      const SizedBox(width: 6),
                    const Icon(Icons.fiber_manual_record, size: 7, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(s.recordProgress!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF333333), fontWeight: FontWeight.w500)),
                  ],
                ]),
              ),
            // 直播标题
            if (s.liveTitle != null && s.liveTitle!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(s.liveTitle!,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFB7299))),
              ),
            // 次要信息：头像 + 备注 + 平台 + 状态
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                if (s.avatar != null && s.avatar!.isNotEmpty)
                  CircleAvatar(radius: 13, backgroundImage: NetworkImage(s.avatar!))
                else
                  const CircleAvatar(radius: 13, backgroundColor: Color(0xFFF0F0F0), child: Icon(Icons.person, size: 14, color: Colors.grey)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(s.remarks.isNotEmpty ? s.remarks : (s.url ?? s.channelId),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _platformColor(s.providerId), borderRadius: BorderRadius.circular(6)),
                  child: Text(plat, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(6)),
                  child: Text(_statusLabel, style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.more_vert, size: 18),
                  padding: EdgeInsets.zero,
                  onPressed: () => onMore(context)),
              ]),
            ),
            if (s.lastRecordTime != null && s.lastRecordTime! > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('上次录制: ${_ago(s.lastRecordTime!)}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            const SizedBox(height: 10),
            // 操作按钮：开/停录（填充高亮）+ 刷新 + 详情
            Row(children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: s.isRecording ? onStop : onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: s.isRecording ? const Color(0x1AF44336) : const Color(0x14FB7299),
                    foregroundColor: s.isRecording ? Colors.red : const Color(0xFFFB7299),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: Text(s.isRecording ? '停止录制' : '开始录制',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onCheck,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                  child: const Text('刷新', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => onDetail(s),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
