import '../models/log_entry.dart';
import '../models/api_response.dart';
import '../models/task.dart' show TaskPriority;
import 'api_client.dart';

class LogService {
  /// 获取日志，可选 keyword/type/startTime/endTime 过滤
  static Future<ApiResponse<List<LogEntry>>> getLogsFiltered({
    String? keyword,
    String? type,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final query = <String>[];

    if (keyword != null && keyword.isNotEmpty) query.add('q=$keyword');
    if (type != null && type.isNotEmpty) query.add('type=$type');
    if (startTime != null) query.add('startTime=${startTime.toIso8601String()}');
    if (endTime != null) query.add('endTime=${endTime.toIso8601String()}');

    final queryString = query.isNotEmpty ? '?${query.join('&')}' : '';

    return await ApiClient.get<List<LogEntry>>(
      '/logs$queryString',
      fromJson: (data) => (data as List)
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 获取所有日志
  static Future<ApiResponse<List<LogEntry>>> getLogs() async {
    return await getLogsFiltered();
  }

  /// 根据 ID 获取日志
  static Future<ApiResponse<LogEntry>> getLogById(String id) async {
    return await ApiClient.get<LogEntry>(
      '/logs/$id',
      fromJson: (data) => LogEntry.fromJson(data as Map<String, dynamic>),
    );
  }

  /// 根据任务 ID 获取日志
  static Future<ApiResponse<List<LogEntry>>> getLogsByTaskId(String taskId) async {
    return await ApiClient.get<List<LogEntry>>(
      '/logs?taskId=$taskId',
      fromJson: (data) => (data as List)
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 创建日志
  static Future<ApiResponse<LogEntry>> createLog(LogEntry log) async {
    final body = {
      'content': log.content,
      'priority': log.priority.name == 'medium' ? 'mid' : log.priority.name,
      'timeFrom': (log.startTime ?? log.time).toIso8601String(),
      'timeTo': log.endTime?.toIso8601String(),
      'taskId': log.taskId != null && log.taskId!.isNotEmpty
          ? int.tryParse(log.taskId!)
          : null,
    };
    return await ApiClient.post<LogEntry>(
      '/logs',
      body: body,
      fromJson: (data) => LogEntry.fromJson(data as Map<String, dynamic>),
    );
  }

  /// 更新日志
  static Future<ApiResponse<LogEntry>> updateLog(LogEntry log) async {
    final body = {
      'content': log.content,
      'priority': log.priority.name == 'medium' ? 'mid' : log.priority.name,
      'timeFrom': (log.startTime ?? log.time).toIso8601String(),
      'timeTo': log.endTime?.toIso8601String(),
      'taskId': log.taskId != null && log.taskId!.isNotEmpty
          ? int.tryParse(log.taskId!)
          : null,
    };
    return await ApiClient.patch<LogEntry>(
      '/logs/${log.id}',
      body: body,
      fromJson: (data) => LogEntry.fromJson(data as Map<String, dynamic>),
    );
  }

  /// 删除日志
  static Future<ApiResponse<void>> deleteLog(String id) async {
    return await ApiClient.delete<void>('/logs/$id');
  }
}

/// 辅助函数：将字符串转换成 TaskPriority
TaskPriority _mapPriority(String? p) {
  switch (p) {
    case 'high':
      return TaskPriority.high;
    case 'mid':
    case 'medium':
      return TaskPriority.medium;
    default:
      return TaskPriority.low;
  }
}
