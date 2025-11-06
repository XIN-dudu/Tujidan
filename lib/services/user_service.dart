import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _tokenKey = 'auth_token';
  static const String _baseUrl = 'http://localhost:3001/api';

  // 获取存储的token
  Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // 获取当前用户基本信息
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final String? token = await _getToken();
      if (token == null) return null;

      // 使用 /api/verify 接口获取当前登录用户信息
      final response = await http.get(
        Uri.parse('$_baseUrl/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['user'] != null) {
          final user = data['user'] as Map<String, dynamic>;
          // 统一转换为下划线格式，保持与前端其他代码一致
          return {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'real_name': user['realName'], // 转换小驼峰为下划线
            'phone': user['phone'],
            'position': user['position'],
            'avatar_url': user['avatarUrl'], // 转换小驼峰为下划线
          };
        }
      }
    } catch (e) {
      print('获取用户信息失败: $e');
    }
    return null;
  }

  // 获取当前用户角色和权限
  Future<Map<String, dynamic>?> getUserPermissions() async {
    try {
      final String? token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/user/permissions'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'roles': data['roles'] ?? [],
            'permissions': data['permissions'] ?? [],
          };
        }
      }
    } catch (e) {
      print('获取用户权限失败: $e');
    }
    return null;
  }

  // 检查用户是否有指定权限
  Future<bool> hasPermission(String permission) async {
    try {
      final permissionsData = await getUserPermissions();
      if (permissionsData == null) return false;

      final List permissions = permissionsData['permissions'] ?? [];
      return permissions.any((perm) => perm['perm_key'] == permission);
    } catch (e) {
      print('检查权限失败: $e');
      return false;
    }
  }

  // 检查用户是否有指定角色
  Future<bool> hasRole(String roleName) async {
    try {
      final permissionsData = await getUserPermissions();
      if (permissionsData == null) return false;

      final List roles = permissionsData['roles'] ?? [];
      return roles.any((role) => role['role_name'] == roleName);
    } catch (e) {
      print('检查角色失败: $e');
      return false;
    }
  }

  // 获取用户角色列表
  Future<List<String>> getUserRoles() async {
    try {
      final permissionsData = await getUserPermissions();
      if (permissionsData == null) return [];

      final List roles = permissionsData['roles'] ?? [];
      return roles.map<String>((role) => role['role_name'] as String).toList();
    } catch (e) {
      print('获取用户角色失败: $e');
      return [];
    }
  }

  // 获取用户权限列表
  Future<List<String>> getUserPermissionKeys() async {
    try {
      final permissionsData = await getUserPermissions();
      if (permissionsData == null) return [];

      final List permissions = permissionsData['permissions'] ?? [];
      return permissions.map<String>((perm) => perm['perm_key'] as String).toList();
    } catch (e) {
      print('获取用户权限失败: $e');
      return [];
    }
  }
}
