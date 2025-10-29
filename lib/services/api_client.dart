import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';

class ApiClient {
  static const String baseUrl = 'http://localhost:3001/api';
  static const Duration timeout = Duration(seconds: 30);

  static Future<Map<String, String>> _authHeaders([Map<String, String>? headers]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?headers,
    };
  }

  static Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _authHeaders(headers),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: '网络请求失败: $e',
      );
    }
  }

  static Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _authHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: '网络请求失败: $e',
      );
    }
  }

  static Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _authHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: '网络请求失败: $e',
      );
    }
  }

  static Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _authHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: '网络请求失败: $e',
      );
    }
  }

  static Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse('$baseUrl$endpoint'),
            headers: await _authHeaders(headers),
          )
          .timeout(timeout);

      return _handleResponse<T>(response, fromJson);
    } catch (e) {
      return ApiResponse<T>(
        success: false,
        message: '网络请求失败: $e',
      );
    }
  }

  static ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? fromJson,
  ) {
    try {
      // 检查是否返回了HTML（通常是错误页面）
      if (response.headers['content-type']?.contains('text/html') == true ||
          response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        return ApiResponse<T>(
          success: false,
          message: '服务器返回了错误页面，可能是接口不存在或服务器错误。状态码: ${response.statusCode}',
          code: response.statusCode,
        );
      }

      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 优先使用 data 字段，否则尝试提取特定字段，如果都没有则使用整个响应对象
        final dynamic payload;
        if (jsonData.containsKey('data')) {
          payload = jsonData['data'];
        } else if (jsonData.containsKey('users')) {
          // 对于 users 接口，返回整个响应对象以便前端访问 users 字段
          payload = jsonData;
        } else {
          payload = (jsonData['log'] ?? jsonData['logs'] ?? jsonData['task'] ?? jsonData['tasks'] ?? jsonData);
        }
        return ApiResponse<T>(
          success: true,
          message: jsonData['message'] ?? '请求成功',
          data: (fromJson != null && (payload != null)) ? fromJson(payload) : null,
          code: response.statusCode,
        );
      } else {
        return ApiResponse<T>(
          success: false,
          message: jsonData['message'] ?? '请求失败',
          code: response.statusCode,
        );
      }
    } catch (e) {
      // 如果响应是HTML，给出更友好的错误提示
      if (response.body.trim().startsWith('<!DOCTYPE') || response.body.trim().startsWith('<html')) {
        return ApiResponse<T>(
          success: false,
          message: '服务器返回了HTML页面而非JSON，可能是接口路径错误或服务器未正确配置。请检查后端服务是否正常运行。',
          code: response.statusCode,
        );
      }
      
      return ApiResponse<T>(
        success: false,
        message: '数据解析失败: $e',
        code: response.statusCode,
      );
    }
  }
}
