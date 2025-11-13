import '../models/api_response.dart';
import '../models/dashboard_log_item.dart';
import 'api_client.dart';

class DashboardService {
  static const int defaultLimit = 8;

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
}

