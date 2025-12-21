import '../models/api_response.dart';
import '../models/dashboard_log_item.dart';
import '../models/dashboard_task_item.dart';
import 'api_client.dart';

class DashboardService {
  static const int defaultLimit = 10;

  /// 获取仪表盘日志（固定 + 自动补充）
  static Future<ApiResponse<List<DashboardLogItem>>> getDashboardLogs({
    int limit = defaultLimit,
  }) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<DashboardLogItem>>(
      '/dashboard/logs$query',
      fromJson: (data) => (data as List)
          .map((item) => DashboardLogItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 固定仪表盘日志
  static Future<ApiResponse<void>> pinLog(String logId) async {
    return await ApiClient.post<void>(
      '/dashboard/logs',
      body: {'logId': logId},
    );
  }

  /// 移除固定的仪表盘日志
  static Future<ApiResponse<void>> unpinLog(String logId) async {
    return await ApiClient.delete<void>('/dashboard/logs/$logId');
  }

  /// 按部门统计被分配任务数量
  /// 返回结构: [{"departmentId": 1, "taskCount": 10}, ...]
  static Future<ApiResponse<List<Map<String, dynamic>>>> getTasksByDepartment({int limit = 50}) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/stats/tasks-by-department$query',
      fromJson: (data) => (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  /// 按部门统计日志关键词
  /// 返回结构: [{"departmentId": 1, "keywords": [{"keyword": "xxx", "count": 10}, ...]}, ...]
  static Future<ApiResponse<List<Map<String, dynamic>>>> getKeywordsByDepartment() async {
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/stats/keywords-by-department',
      fromJson: (data) => (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }

  /// 获取仪表盘任务
  static Future<ApiResponse<List<DashboardTaskItem>>> getDashboardTasks({
    int limit = defaultLimit,
  }) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<DashboardTaskItem>>(
      '/dashboard/tasks$query',
      fromJson: (data) => (data as List)
          .map((item) => DashboardTaskItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// 添加仪表盘任务
  static Future<ApiResponse<void>> pinTask(String taskId) async {
    return await ApiClient.post<void>(
      '/dashboard/tasks',
      body: {'taskId': taskId},
    );
  }

  /// 移除仪表盘任务
  static Future<ApiResponse<void>> unpinTask(String taskId) async {
    return await ApiClient.delete<void>('/dashboard/tasks/$taskId');
  }
}

