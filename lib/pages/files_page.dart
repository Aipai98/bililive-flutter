import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/file_item.dart';
import '../services/api_service.dart';

class FilesPage extends StatefulWidget {
  final ApiService api;
  const FilesPage({super.key, required this.api});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  List<FileItem> _list = [];
  bool _loading = false;
  bool _canDelete = false;
  String _currentPath = '';
  String _parentPath = '';
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.getFileList(_currentPath);
      setState(() {
        _parentPath = r.parentPath ?? '';
        if (r.currentPath.isNotEmpty) _currentPath = r.currentPath;
        _canDelete = r.deleteEnabled;
        _list = r.list;
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

  IconData _icon(FileItem f) {
    if (f.isDir) return Icons.folder;
    switch (f.ext) {
      case 'mp4': case 'flv': case 'ts': case 'mkv': case 'avi':
      case 'mov': case 'wmv': case 'webm': case 'm4s':
        return Icons.movie;
      case 'xml': case 'json':
        return Icons.description;
      case 'mp3': case 'wav': case 'aac':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _iconBg(FileItem f) {
    if (f.isDir) return const Color(0xFFE3F2FD);
    switch (f.ext) {
      case 'mp4': case 'flv': case 'ts': case 'mkv': case 'avi':
      case 'mov': case 'wmv': case 'webm': case 'm4s':
        return const Color(0xFFFBE9E7);
      case 'xml': case 'json':
        return const Color(0xFFE8F5E9);
      case 'mp3': case 'wav': case 'aac':
        return const Color(0xFFFCE4EC);
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  void _onTap(FileItem f) {
    if (f.isDir) {
      _currentPath = f.path;
      _load();
    } else if (f.isVideo) {
      _play(f);
    } else {
      _copy(f.path);
    }
  }

  Future<void> _play(FileItem f) async {
    final url = '${widget.api.baseUrl}/files/download?path=${Uri.encodeQueryComponent(f.path)}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _copy(url);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无播放器，已复制链接')));
      }
    } catch (_) {
      _copy(url);
    }
  }

  void _copy(String p) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已复制: $p')));
  }

  void _showMenu(FileItem f, BuildContext ctx) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!f.isDir) ...[
            if (_canDelete)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(f);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制路径'),
              onTap: () { Navigator.pop(context); _copy(f.path); },
            ),
            if (f.isVideo)
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('播放'),
                onTap: () { Navigator.pop(context); _play(f); },
              ),
          ] else
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制路径'),
              onTap: () { Navigator.pop(context); _copy(f.path); },
            ),
        ]),
      ),
    );
  }

  void _confirmDelete(FileItem f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除「${f.name}」？\n\n${f.path}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.api.deleteFile(f.path);
                if (mounted) ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('已删除: ${f.name}')));
                _load();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('删除失败: $e')));
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPath.isEmpty ? '文件（录制目录）' : _currentPath),
        actions: [
          if (_parentPath.isNotEmpty)
            IconButton(icon: const Icon(Icons.arrow_upward), onPressed: () {
              _currentPath = _parentPath;
              _load();
            }),
        ],
      ),
      body: Column(
        children: [
          if (!_canDelete && !_loading && _err == null)
            Container(
              width: double.infinity,
              color: Colors.orange.shade50,
              padding: const EdgeInsets.all(10),
              child: const Text(
                '当前后端未开启文件删除权限（deleteEnabled=false），无法在 App 内删除文件。'
                '如需开启，请在你 biliLive-tools 的配置中允许文件删除后重试。',
                style: TextStyle(fontSize: 12, color: Colors.deepOrange),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _err != null
                    ? Center(child: Text('加载失败: $_err'))
                    : _list.isEmpty
                        ? const Center(child: Text('空目录'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(6),
                              itemCount: _list.length,
                              itemBuilder: (_, i) {
                                final f = _list[i];
                                return Card(
                                  margin: const EdgeInsets.all(6),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _iconBg(f),
                                      child: Icon(_icon(f), color: Colors.black54),
                                    ),
                                    title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                      f.isDir ? '文件夹'
                                          : '${_fmtSize(f.size)}${f.mtimeMs > 0 ? ' · ${_fmtDate(f.mtimeMs)}' : ''}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    trailing: f.isDir ? null : IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () => _showMenu(f, context),
                                    ),
                                    onTap: () => _onTap(f),
                                    onLongPress: f.isDir ? null : () => _showMenu(f, context),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

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
