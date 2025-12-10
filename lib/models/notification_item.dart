import 'dart:developer';

enum NotificationType {
  assignment,
  statusChange,
  logCreated,
  progressUpdate,
  deadlineSoon,
  deadlinePassed,
  logDeadlineSoon,
  logDeadlinePassed,
  taskUpdate,
  logUpdate,
  unknown,
}

NotificationType _notificationTypeFromString(String? type) {
  switch (type) {
    case 'assignment':
      return NotificationType.assignment;
    case 'status_change':
      return NotificationType.statusChange;
    case 'log_created':
      return NotificationType.logCreated;
    case 'progress_update':
      return NotificationType.progressUpdate;
    case 'deadline_soon':
      return NotificationType.deadlineSoon;
    case 'deadline_passed':
      return NotificationType.deadlinePassed;
    case 'log_deadline_soon':
      return NotificationType.logDeadlineSoon;
    case 'log_deadline_passed':
      return NotificationType.logDeadlinePassed;
    case 'task_update':
      return NotificationType.taskUpdate;
    case 'log_update':
      return NotificationType.logUpdate;
    default:
      log('Unknown notification type: $type');
      return NotificationType.unknown;
  }
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String? content;
  final DateTime timestamp;
  final String? relatedId; // 关联的ID
  final String? entityType; // 关联的实体类型: 'task' 或 'log'
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    required this.timestamp,
    this.relatedId,
    this.entityType,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'].toString(),
      type: _notificationTypeFromString(json['type']),
      title: json['title'],
      content: json['content'],
      timestamp: DateTime.parse(json['created_at']),
      relatedId: json['related_id']?.toString(),
      entityType: json['entity_type'], // 新增字段
      // MySQL BOOLEAN is returned as 0 or 1
      isRead: json['is_read'] == 1 || json['is_read'] == true,
    );
  }
}