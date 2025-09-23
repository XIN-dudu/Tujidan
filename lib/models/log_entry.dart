import 'task.dart';

class LogEntry {
  final String id;
  final String content;
  final String? taskId;
  final TaskPriority priority;
  final DateTime time;
  final DateTime createdAt;
  final DateTime updatedAt;

  LogEntry({
    required this.id,
    required this.content,
    this.taskId,
    required this.priority,
    required this.time,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    return LogEntry(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      taskId: json['taskId'],
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.low,
      ),
      time: DateTime.parse(json['time'] ?? DateTime.now().toIso8601String()),
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
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
  }) {
    return LogEntry(
      id: id ?? this.id,
      content: content ?? this.content,
      taskId: taskId ?? this.taskId,
      priority: priority ?? this.priority,
      time: time ?? this.time,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
