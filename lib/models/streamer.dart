class Streamer {
  final String id;
  final String providerId;
  final String channelId;
  final String remarks;
  final bool disableAutoCheck;
  final String? url;
  final String? avatar;
  final String? cover;
  final String? liveTitle;
  final String? state;
  final int? lastRecordTime;
  final Map<String, dynamic>? extra;
  final Map<String, dynamic>? liveInfo;
  // 正在录制时才有：使用的画质（如"原画1080P60"）和已录制时长（如"00:34:21"）
  final String? usedStream;
  final String? recordProgress;

  Streamer({
    required this.id,
    required this.providerId,
    required this.channelId,
    required this.remarks,
    this.disableAutoCheck = false,
    this.url,
    this.avatar,
    this.cover,
    this.liveTitle,
    this.state,
    this.lastRecordTime,
    this.extra,
    this.liveInfo,
    this.usedStream,
    this.recordProgress,
  });

  factory Streamer.fromJson(Map<String, dynamic> j) {
    final extra = j['extra'] as Map<String, dynamic>?;
    final liveInfo = j['liveInfo'] as Map<String, dynamic>?;
    final recordHandle = j['recordHandle'] as Map<String, dynamic>?;
    final progress = recordHandle?['progress'] as Map<String, dynamic>?;
    return Streamer(
      id: j['id']?.toString() ?? '',
      providerId: j['providerId']?.toString() ?? '',
      channelId: j['channelId']?.toString() ?? '',
      remarks: j['remarks']?.toString() ?? '',
      disableAutoCheck: j['disableAutoCheck'] as bool? ?? false,
      url: j['channelURL']?.toString(),
      avatar: extra?['avatar']?.toString(),
      cover: extra?['cover']?.toString() ?? extra?['avatar']?.toString(),
      liveTitle: liveInfo?['title']?.toString(),
      state: j['state']?.toString(),
      lastRecordTime: _parseMtime(extra?['lastRecordTime']),
      liveInfo: liveInfo,
      extra: extra,
      // 画质优先取顶层 usedStream，回退到 recordHandle.stream
      usedStream:
          j['usedStream']?.toString() ?? recordHandle?['stream']?.toString(),
      recordProgress: progress?['time']?.toString(),
    );
  }

  static int? _parseMtime(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  bool get isRecording => state == 'recording';
  bool get liveStatus =>
      (liveInfo?['living'] as bool? ?? false) || state == 'checking';

  String get name => remarks.isNotEmpty ? remarks : (url ?? channelId);
}

class StreamerStatistics {
  final String totalDuration;
  final int recordingNum;
  final int recorderNum;
  StreamerStatistics({
    required this.totalDuration,
    required this.recordingNum,
    required this.recorderNum,
  });
}
