import 'task.dart';

class LogEntry {
  final String id;
  final String content;
  final String? taskId;
  final TaskPriority priority;
  final DateTime time;       // 原本日志时间
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startTime; // 新增：开始时间
  final DateTime? endTime;   // 新增：结束时间

  LogEntry({
    required this.id,
    required this.content,
    this.taskId,
    required this.priority,
    required this.time,
    required this.createdAt,
    required this.updatedAt,
    this.startTime,
    this.endTime,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    String toStringValue(dynamic v) => v == null ? '' : v.toString();
    String? toNullableString(dynamic v) => v == null ? null : v.toString();
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
      content: (json['content'] ?? '').toString(),
      taskId: toNullableString(json['taskId'] ?? json['task_id']),
      priority: parsePriority(json['priority']),
      // 优先使用后端的开始时间，其次 time/time_from，最后才用 createdAt
      time: parseTime(json['startTime'] ?? json['start_time'] ?? json['time'] ?? json['time_from'] ?? json['createdAt'] ?? json['created_at']),
      createdAt: parseTime(json['createdAt'] ?? json['created_at']),
      updatedAt: parseTime(json['updatedAt'] ?? json['updated_at']),
      startTime: json['startTime'] != null
          ? parseTime(json['startTime'])
          : (json['start_time'] != null ? parseTime(json['start_time']) : null),
      endTime: json['endTime'] != null
          ? parseTime(json['endTime'])
          : (json['end_time'] != null ? parseTime(json['end_time']) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'taskId': taskId,
      'priority': priority.name,
      'time': time.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
    };
  }

  LogEntry copyWith({
    String? id,
    String? content,
    String? taskId,
    TaskPriority? priority,
    DateTime? time,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    return LogEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      taskId: taskId ?? this.taskId,
      priority: priority ?? this.priority,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}
