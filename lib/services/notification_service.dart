import '../models/notification_item.dart';
import '../models/task.dart';
import '../models/log_entry.dart';
import 'task_service.dart';
import 'log_service.dart';

class NotificationService {
  /// 获取所有通知
  static Future<List<NotificationItem>> getNotifications() async {
    final notifications = <NotificationItem>[];

    // 获取任务通知
    try {
      final taskResponse = await TaskService.getTasks();
      if (taskResponse.success && taskResponse.data != null) {
        for (final task in taskResponse.data!) {
          // 任务分配通知 (假设新创建的任务就是分配)
          notifications.add(NotificationItem(
            id: 'task-${task.id}-assigned',
            type: NotificationType.taskAssigned,
            title: '新任务: ${task.name}',
            content: task.description,
            timestamp: task.createdAt ?? DateTime.now(),
            relatedId: task.id.toString(),
          ));

          // 任务截止日期通知
          if (task.deadline.isAfter(DateTime.now())) {
            notifications.add(NotificationItem(
              id: 'task-${task.id}-deadline',
              type: NotificationType.taskDeadline,
              title: '任务即将截止: ${task.name}',
              content: '截止日期: ${task.deadline}',
              timestamp: task.deadline,
              relatedId: task.id.toString(),
            ));
          }
        }
      }
    } catch (e) {
      // 处理异常
    }

    // 获取日志截止日期通知
    try {
      final logResponse = await LogService.getLogs();
      if (logResponse.success && logResponse.data != null) {
        for (final log in logResponse.data!) {
          if (log.endTime != null && log.endTime!.isAfter(DateTime.now())) {
            notifications.add(NotificationItem(
              id: 'log-${log.id}-deadline',
              type: NotificationType.logDeadline,
              title: '日志即将截止: ${log.title}',
              content: '截止日期: ${log.endTime}',
              timestamp: log.endTime!,
              relatedId: log.id,
            ));
          }
        }
      }
    } catch (e) {
      // 处理异常
    }

    // 按时间倒序排序
    notifications.sort((a, b) { return b.timestamp.compareTo(a.timestamp); });

    return notifications;
  }
}