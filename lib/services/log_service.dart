import '../models/log_entry.dart';
import '../models/api_response.dart';
import '../models/task.dart' show TaskPriority;
import 'api_client.dart';

class LogService {
  // 获取所有日志（当前用户）
  static Future<ApiResponse<List<LogEntry>>> getLogs() async {
    LogEntry _map(dynamic item) {
      final m = item as Map<String, dynamic>;
      return LogEntry(
        id: '${m['id'] ?? ''}',
        content: m['content'] ?? '',
        taskId: m['task_id']?.toString(),
        priority: _mapPriority(m['priority'] as String?),
        time: _parseTime(m['time_from'] ?? m['time'] ?? m['created_at']),
        createdAt: _parseTime(m['created_at']),
        updatedAt: _parseTime(m['updated_at']),
      );
    }

    final resp = await ApiClient.get<List<LogEntry>>('/logs',
        fromJson: (data) => (data as List).map(_map).toList());
    return resp;
  }

  // 根据ID获取日志
  static Future<ApiResponse<LogEntry>> getLogById(String id) async {
    return await ApiClient.get<LogEntry>(
      '/logs/$id',
      fromJson: (data) => LogEntry.fromJson(data as Map<String, dynamic>),
    );
  }

  // 根据任务ID获取相关日志
  static Future<ApiResponse<List<LogEntry>>> getLogsByTaskId(String taskId) async {
    return await ApiClient.get<List<LogEntry>>(
      '/logs?taskId=$taskId',
      fromJson: (data) => (data as List)
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // 创建日志
  static Future<ApiResponse<LogEntry>> createLog(LogEntry log) async {
    final body = {
      'content': log.content,
      'priority': log.priority.name == 'medium' ? 'mid' : log.priority.name, // 映射 medium->mid
      'progress': 0,
      'timeFrom': log.time.toIso8601String(),
      'timeTo': null,
      'taskId': log.taskId != null && log.taskId!.isNotEmpty ? int.tryParse(log.taskId!) : null,
      'syncTaskProgress': false,
    };
    LogEntry _map(dynamic data) {
      final m = data as Map<String, dynamic>;
      return LogEntry(
        id: '${m['id'] ?? ''}',
        content: m['content'] ?? '',
        taskId: m['task_id']?.toString(),
        priority: _mapPriority(m['priority'] as String?),
        time: _parseTime(m['time_from'] ?? m['time'] ?? m['created_at']),
        createdAt: _parseTime(m['created_at']),
        updatedAt: _parseTime(m['updated_at']),
      );
    }
    return await ApiClient.post<LogEntry>('/logs', body: body, fromJson: _map);
  }

  // 更新日志
  static Future<ApiResponse<LogEntry>> updateLog(LogEntry log) async {
    final body = {
      'content': log.content,
      'priority': log.priority.name == 'medium' ? 'mid' : log.priority.name,
      'progress': null,
      'timeFrom': log.time.toIso8601String(),
      'timeTo': null,
      'taskId': log.taskId != null && log.taskId!.isNotEmpty ? int.tryParse(log.taskId!) : null,
      'syncTaskProgress': false,
    };
    LogEntry _map(dynamic data) {
      final m = data as Map<String, dynamic>;
      return LogEntry(
        id: '${m['id'] ?? ''}',
        content: m['content'] ?? '',
        taskId: m['task_id']?.toString(),
        priority: _mapPriority(m['priority'] as String?),
        time: _parseTime(m['time_from'] ?? m['time'] ?? m['updated_at']),
        createdAt: _parseTime(m['created_at']),
        updatedAt: _parseTime(m['updated_at']),
      );
    }
    // 优先尝试 PATCH，保持与后端 simple_server_final.js 的 PATCH /api/logs/:id 一致
    return await ApiClient.patch<LogEntry>('/logs/${log.id}', body: body, fromJson: _map);
  }

  // 删除日志
  static Future<ApiResponse<void>> deleteLog(String id) async {
    return await ApiClient.delete<void>('/logs/$id');
  }

  // 搜索日志
  static Future<ApiResponse<List<LogEntry>>> searchLogs(String query) async {
    return await ApiClient.get<List<LogEntry>>(
      '/logs/search?q=$query',
      fromJson: (data) => (data as List)
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // 根据时间范围获取日志
  static Future<ApiResponse<List<LogEntry>>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final start = startDate.toIso8601String();
    final end = endDate.toIso8601String();
    
    return await ApiClient.get<List<LogEntry>>(
      '/logs?startDate=$start&endDate=$end',
      fromJson: (data) => (data as List)
          .map((item) => LogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

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

DateTime _parseTime(dynamic v) {
  if (v == null) return DateTime.now();
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return DateTime.now();
  }
}
