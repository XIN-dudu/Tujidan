import 'api_client.dart';

class LogKeywordService {
  /// 获取时间范围内所有日志的关键词（批量获取）
  /// 返回 Map<String, List<String>>，key 为日志 ID
  static Future<Map<String, List<String>>> getKeywordsRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final startStr = start.toIso8601String();
      final endStr = end.toIso8601String();
      final response = await ApiClient.get(
        '/logs/keywords?startTime=$startStr&endTime=$endStr',
      );

      if (response.success && response.data != null) {
        // response.data 应该是包含完整响应的 Map
        final rawResponse = response.data as Map<String, dynamic>;
        if (rawResponse['data'] is Map) {
          final Map<String, dynamic> rawData = rawResponse['data'];
          final Map<String, List<String>> result = {};
          
          rawData.forEach((logId, keywords) {
            if (keywords is List) {
              result[logId] = keywords
                  .map((kw) => kw['keyword'] as String)
                  .toList();
            }
          });
          
          return result;
        }
      }
      return {};
    } catch (e) {
      print('获取关键词范围失败: $e');
      return {};
    }
  }

  /// 获取单个日志的关键词
  static Future<List<String>> getKeywordsByLogId(String logId) async {
    try {
      final response = await ApiClient.get('/logs/$logId/keywords');

      if (response.success && response.data != null) {
        final rawResponse = response.data as Map<String, dynamic>;
        if (rawResponse['data'] is List) {
          return (rawResponse['data'] as List)
              .map((item) => item['keyword'] as String)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('获取日志 $logId 的关键词失败: $e');
      return [];
    }
  }
}

