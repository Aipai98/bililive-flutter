class FileItem {
  final String name;
  final String path;
  final bool isDir;
  final int size;
  final int mtimeMs;
  final String? fileKind;

  FileItem({
    required this.name,
    required this.path,
    required this.isDir,
    this.size = 0,
    this.mtimeMs = 0,
    this.fileKind,
  });

  factory FileItem.fromJson(Map<String, dynamic> j) {
    final kind = j['fileKind']?.toString();
    // 兼容 size 可能是字符串
    dynamic sz = j['size'];
    int size = 0;
    if (sz is int) size = sz;
    else if (sz is double) size = sz.toInt();
    else if (sz is String) size = int.tryParse(sz) ?? 0;

    dynamic mt = j['mtimeMs'];
    int mtime = 0;
    if (mt is int) mtime = mt;
    else if (mt is double) mtime = mt.toInt();
    else if (mt is String) mtime = int.tryParse(mt) ?? 0;

    return FileItem(
      name: j['name']?.toString() ?? '',
      path: j['path']?.toString() ?? '',
      isDir: j['type']?.toString() == 'directory',
      size: size,
      mtimeMs: mtime,
      fileKind: kind,
    );
  }

  String get ext {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  bool get isVideo {
    const v = {'mp4', 'flv', 'ts', 'mkv', 'avi', 'mov', 'wmv', 'webm', 'm4s'};
    return v.contains(ext);
  }
}

class FileListResponse {
  final String rootPath;
  final String currentPath;
  final String? parentPath;
  final bool deleteEnabled;
  final List<FileItem> list;
  FileListResponse({
    required this.rootPath,
    required this.currentPath,
    this.parentPath,
    this.deleteEnabled = false,
    required this.list,
  });

  factory FileListResponse.fromJson(Map<String, dynamic> j) {
    final arr = (j['list'] as List?) ?? [];
    return FileListResponse(
      rootPath: j['rootPath']?.toString() ?? '',
      currentPath: j['currentPath']?.toString() ?? '',
      parentPath: j['parentPath']?.toString(),
      deleteEnabled: j['deleteEnabled'] as bool? ?? false,
      list: arr.map((e) => FileItem.fromJson(e)).toList(),
    );
  }
}
