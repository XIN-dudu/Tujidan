enum NotificationType {
  taskAssigned,
  taskDeadline,
  logDeadline,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String? content;
  final DateTime timestamp;
  final String? relatedId; // 关联的任务或日志 ID

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    required this.timestamp,
    this.relatedId,
  });
}