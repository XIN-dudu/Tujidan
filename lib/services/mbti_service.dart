import 'api_client.dart';

class MBTIService {
  /// 获取职业发展规划建议
  static Future<Map<String, dynamic>?> getMBTIAnalysis({
    DateTime? startTime,
    DateTime? endTime,
    bool force = false,
  }) async {
    try {
      String endpoint = '/user/mbti-analysis';
      List<String> params = [];
      
      if (startTime != null && endTime != null) {
        params.add('startTime=${startTime.toIso8601String()}');
        params.add('endTime=${endTime.toIso8601String()}');
      }
      if (force) params.add('force=1');
      
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final response = await ApiClient.get<Map<String, dynamic>>(
        endpoint,
        fromJson: (payload) => payload as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('获取职业规划失败: $e');
      return null;
    }
  }

  /// 获取发展建议
  static Future<Map<String, dynamic>?> getDevelopmentSuggestions({
    required String mbti,
    DateTime? startTime,
    DateTime? endTime,
    bool force = false,
  }) async {
    try {
      String endpoint = '/user/development-suggestions?mbti=$mbti';
      
      if (startTime != null && endTime != null) {
        endpoint += '&startTime=${startTime.toIso8601String()}';
        endpoint += '&endTime=${endTime.toIso8601String()}';
      }
      if (force) endpoint += '&force=1';

      final response = await ApiClient.get<Map<String, dynamic>>(
        endpoint,
        fromJson: (payload) => payload as Map<String, dynamic>,
      );

      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('获取发展建议失败: $e');
      return null;
    }
  }
}

