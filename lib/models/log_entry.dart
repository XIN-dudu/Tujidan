import 'task.dart';

class LogLocation {
  final double latitude;
  final double longitude;
  final String? address;

  LogLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  @override
  String toString() {
    if (address != null && address!.isNotEmpty) {
      return address!;
    }
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}

class LogEntry {
  final String id;
  final String title; // 新增：日志标题
  final String content;
  final String? type; // 新增：日志类型
  final String? taskId;
  final TaskPriority priority;
  final DateTime time; // 原本日志时间
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startTime; // 新增：开始时间
  final DateTime? endTime; // 新增：结束时间
  final String logStatus; // 主要状态字段：in_progress, completed
  final bool isCompleted; // 新增：完成状态（从logStatus派生）
  final List<String> images;
  final LogLocation? location; // 地理位置信息
  final String? authorUserId; // 创建人ID
  final String? authorUsername; // 创建人用户名
  final String? authorRealName; // 创建人真实姓名

  LogEntry({
    required this.id,
    required this.title,
    required this.content,
    this.type,
    this.taskId,
    required this.priority,
    required this.time,
    required this.createdAt,
    required this.updatedAt,
    this.startTime,
    this.endTime,
    this.logStatus = 'pending',
    bool? isCompleted,
    List<String>? images,
    this.location,
    this.authorUserId,
    this.authorUsername,
    this.authorRealName,
  }) : images = images ?? const [],
       isCompleted = isCompleted ?? (logStatus == 'completed');

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    String toStringValue(dynamic v) => v == null ? '' : v.toString();
    String? toNullableString(dynamic v) => v == null ? null : v.toString();
    String? parseTaskId(dynamic v) {
      if (v == null) return null;
      return v.toString(); // 直接转换为字符串，因为后端总是返回整数
    }

    TaskPriority parsePriority(dynamic v) {
      final s = (v ?? '').toString();
      switch (s) {
        case 'high':
          return TaskPriority.high;
        case 'mid':
        case 'medium':
          return TaskPriority.medium;
        default:
          return TaskPriority.low;
      }
    }

    DateTime parseTime(dynamic v) {
      if (v == null) return DateTime.now();
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return LogEntry(
      id: toStringValue(json['id']),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      type: toNullableString(json['type'] ?? json['log_type']),
      taskId: parseTaskId(json['taskId'] ?? json['task_id']),
      priority: parsePriority(json['priority']),
      // 优先使用后端的开始时间，其次 time/time_from，最后才用 createdAt
      time: parseTime(
        json['startTime'] ??
            json['start_time'] ??
            json['time'] ??
            json['time_from'] ??
            json['createdAt'] ??
            json['created_at'],
      ),
      createdAt: parseTime(json['createdAt'] ?? json['created_at']),
      updatedAt: parseTime(json['updatedAt'] ?? json['updated_at']),
      startTime: json['startTime'] != null
          ? parseTime(json['startTime'])
          : (json['start_time'] != null ? parseTime(json['start_time']) : null),
      endTime: json['endTime'] != null
          ? parseTime(json['endTime'])
          : (json['end_time'] != null ? parseTime(json['end_time']) : null),
      logStatus: _normalizeLogStatus(json['log_status'] ?? json['logStatus']),
      images: _parseImages(json['images']),
      location: _parseLocation(json['location']),
      authorUserId: toNullableString(json['authorUserId'] ?? json['author_user_id'] ?? json['userId']),
      authorUsername: toNullableString(json['authorUsername'] ?? json['author_username']),
      authorRealName: toNullableString(json['authorRealName'] ?? json['author_real_name']),
    );
  }

  static List<String> _parseImages(dynamic source) {
    if (source is List) {
      return source
          .map((item) {
            if (item is String) return item;
            if (item is Map<String, dynamic>) {
              return item['dataUri']?.toString() ??
                  item['image_data']?.toString();
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }
    return const [];
  }

  static LogLocation? _parseLocation(dynamic source) {
    if (source == null) return null;
    if (source is Map<String, dynamic>) {
      final lat = source['latitude'];
      final lng = source['longitude'];
      if (lat != null && lng != null) {
        return LogLocation(
          latitude: (lat is num) ? lat.toDouble() : double.tryParse(lat.toString()) ?? 0.0,
          longitude: (lng is num) ? lng.toDouble() : double.tryParse(lng.toString()) ?? 0.0,
          address: source['address']?.toString(),
        );
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'taskId': taskId,
      'priority': priority.name,
      'time': time.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'log_status': logStatus,
      'isCompleted': isCompleted,
      'images': images,
      'location': location?.toJson(),
    };
  }

  LogEntry copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    String? taskId,
    TaskPriority? priority,
    DateTime? time,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startTime,
    DateTime? endTime,
    String? logStatus,
    bool? isCompleted,
    List<String>? images,
    LogLocation? location,
    String? authorUserId,
    String? authorUsername,
    String? authorRealName,
  }) {
    final newLogStatus = logStatus ?? this.logStatus;
    return LogEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      taskId: taskId ?? this.taskId,
      priority: priority ?? this.priority,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      logStatus: newLogStatus,
      isCompleted: isCompleted,
      images: images ?? this.images,
      location: location ?? this.location,
      authorUserId: authorUserId ?? this.authorUserId,
      authorUsername: authorUsername ?? this.authorUsername,
      authorRealName: authorRealName ?? this.authorRealName,
    );
  }

  // 便捷方法：标记为完成
  LogEntry markAsCompleted() {
    return copyWith(logStatus: 'completed');
  }

  // 便捷方法：标记为未完成
  LogEntry markAsIncomplete() {
    return copyWith(logStatus: 'pending');
  }

  // 静态方法：规范化状态值
  static String _normalizeLogStatus(dynamic status) {
    if (status == null) return 'in_progress';
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'completed':
      case 'done':
      case 'finished':
        return 'completed';
      case 'in_progress':
      case 'inprogress':
      case 'ongoing':
      case 'active':
        return 'in_progress';
      case 'pending':
      case 'cancelled':
      case 'canceled':
        // 兼容旧数据，将 pending 和 cancelled 都映射为 in_progress
        return 'in_progress';
      default:
        return 'in_progress';
    }
  }
}
