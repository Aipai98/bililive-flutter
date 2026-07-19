import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/streamer.dart';
import '../models/file_item.dart';

class ApiException implements Exception {
  final String msg;
  ApiException(this.msg);
  @override
  String toString() => msg;
}

class ApiService {
  String _baseUrl = '';
  String _pass = '';
  String _prefix = '';

  String get baseUrl => _baseUrl;
  String get prefix => _prefix;

  void setConfig(String baseUrl, String pass, [String prefix = '']) {
    _baseUrl = baseUrl.trim();
    if (_baseUrl.endsWith('/')) _baseUrl = _baseUrl.substring(0, _baseUrl.length - 1);
    _pass = pass.trim();
    _prefix = prefix;
  }

  bool get configured =>
      _baseUrl.startsWith('http://') || _baseUrl.startsWith('https://');

  Uri _uri(String path) => Uri.parse('$_baseUrl$_prefix$path');

  Map<String, String> get _headers => {'Authorization': _pass};

  Future<String> _get(String path) async {
    final r = await http.get(_uri(path), headers: _headers);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body;
    throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<String> _post(String path, String body) async {
    final r = await http.post(_uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'}, body: body);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body;
    throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<String> _put(String path, String body) async {
    final r = await http.put(_uri(path),
        headers: {..._headers, 'Content-Type': 'application/json'}, body: body);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body;
    throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  Future<String> _delete(String path) async {
    final r = await http.delete(_uri(path), headers: _headers);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.body;
    throw ApiException('HTTP ${r.statusCode}: ${r.body}');
  }

  // ---- 连通性（自动探 /api 前缀） ----
  Future<String> testConnection() async {
    if (!configured) throw ApiException('请先填写后台地址');
    try {
      final raw = await _get('/common/version');
      if (_looksJson(raw)) {
        _prefix = '';
        return '连接成功（直连后台）';
      }
    } catch (_) {}
    // 试 /api 前缀
    try {
      final raw = await http
          .get(_uri('/api/common/version'), headers: _headers);
      if (raw.statusCode >= 200 && raw.statusCode < 300 && _looksJson(raw.body)) {
        _prefix = '/api';
        return '连接成功（/api 前缀）';
      }
    } catch (_) {}
    throw ApiException('连接失败：地址或密码错误');
  }

  bool _looksJson(String s) {
    final t = s.trim();
    return t.startsWith('{') || t.startsWith('[') || t.startsWith('"');
  }

  // ---- 主播列表 ----
  Future<List<Streamer>> getStreamerList() async {
    final raw = await _get('/recorder/list');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final payload = j['payload'] is Map ? j['payload'] as Map<String, dynamic> : j;
    final data = payload['data'] is List ? payload['data'] as List : [];
    return data
        .map((e) => Streamer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getStreamerDetail(String id) async {
    final raw = await _get('/recorder/$id');
    final j = jsonDecode(raw);
    return j['payload'] is Map ? j['payload'] : j;
  }

  Future<void> addStreamer(String providerId, String channelId, String remarks) async {
    final body = jsonEncode({
      'providerId': providerId,
      'channelId': channelId,
      if (remarks.isNotEmpty) 'remarks': remarks,
    });
    await _post('/recorder/add', body);
  }

  Future<void> updateStreamer(
      String id, String providerId, String channelId, String remarks) async {
    final body = jsonEncode({
      'providerId': providerId,
      'channelId': channelId,
      if (remarks.isNotEmpty) 'remarks': remarks,
    });
    await _put('/recorder/$id', body);
  }

  Future<void> deleteStreamer(String id) async => _delete('/recorder/$id');

  Future<void> startRecord(String id) async => _post('/recorder/$id/start_record', '{}');
  Future<void> stopRecord(String id) async => _post('/recorder/$id/stop_record', '{}');
  Future<void> checkStreamer(String id) async => _get('/recorder/$id');

  // ---- 统计 ----
  Future<Map<String, dynamic>> getStatistics() async {
    final raw = await _get('/common/statistics');
    final j = jsonDecode(raw);
    if (j is Map<String, dynamic> && j['payload'] is Map) {
      return j['payload'] as Map<String, dynamic>;
    }
    return j as Map<String, dynamic>;
  }

  // ---- 文件 ----
  Future<FileListResponse> getFileList(String path) async {
    final enc = Uri.encodeQueryComponent(path.isEmpty ? '' : path);
    final raw = await _get('/files/list?path=$enc');
    return FileListResponse.fromJson(jsonDecode(raw));
  }

  Future<void> deleteFile(String path) async {
    final body = jsonEncode({'path': path});
    await _post('/files/delete', body);
  }
}
