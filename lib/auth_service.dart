import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/server_config.dart';
import 'services/user_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  
  // 获取存储的token
  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 保存token到本地存储
  Future<void> _saveToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // 检查用户是否已登录
  Future<bool> isLoggedIn() async {
    final String? token = await _getToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    // 验证token是否有效
    try {
      final baseUrl = await ServerConfig.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('验证token失败: $e');
    }
    
    return false;
  }

  // 用户登录
  Future<String?> login({required String username, required String password}) async {
    try {
      final baseUrl = await ServerConfig.getBaseUrl();
      // 发送登录请求到后端，设置超时
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 30));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // 登录成功，保存token
        await _saveToken(data['token']);
        // 清除旧账号的头像缓存
        UserService.clearAvatarCache();
        return null; // 返回null表示成功
      } else {
        // 登录失败，返回错误信息
        return data['message'] ?? '登录失败';
      }
    } catch (e) {
      print('登录请求失败: $e');
      if (e.toString().contains('TimeoutException')) {
        return '请求超时，请检查网络连接';
      }
      return '网络连接失败，请检查网络设置';
    }
  }

  // 用户登出
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    
    // 清除头像缓存
    // 注意：需要导入 UserService 才能调用
    // 为了避免循环依赖，我们在 UserService 中提供静态方法
  }

  // 获取当前用户信息
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final String? token = await _getToken();
    if (token == null) return null;

    try {
      final baseUrl = await ServerConfig.getBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['user'];
        }
      }
    } catch (e) {
      print('获取用户信息失败: $e');
    }
    
    return null;
  }
}



