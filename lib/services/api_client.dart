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
      final Map<String, dynamic> jsonData = jsonDecode(response.body);
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic payload = jsonData.containsKey('data')
            ? jsonData['data']
            : (jsonData['log'] ?? jsonData['logs'] ?? jsonData['task'] ?? jsonData['tasks']);
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
      return ApiResponse<T>(
        success: false,
        message: '数据解析失败: $e',
        code: response.statusCode,
      );
    }
  }
}
