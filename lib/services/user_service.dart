import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static const String _tokenKey = 'auth_token';
  static const String _baseUrl = 'http://localhost:3001/api';
  
  // 头像缓存：存储解码后的 ImageProvider 和用户ID
  static ImageProvider? _cachedAvatarImage;
  static String? _cachedAvatarUrl;
  static int? _cachedUserId; // 缓存用户ID，用于检测账号切换

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
          final userId = user['id'] as int?;
          final avatarUrl = user['avatarUrl'] as String?;
          
          // 如果用户ID变化，清除旧缓存
          if (userId != null && userId != _cachedUserId) {
            _cachedAvatarImage = null;
            _cachedAvatarUrl = null;
            _cachedUserId = userId;
          }
          
          // 如果头像URL存在且与缓存的不同，则解码并缓存
          if (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != _cachedAvatarUrl) {
            _cacheAvatarImage(avatarUrl);
            _cachedUserId = userId;
          } else if (avatarUrl == null || avatarUrl.isEmpty) {
            // 如果新用户没有头像，清除缓存
            _cachedAvatarImage = null;
            _cachedAvatarUrl = null;
            _cachedUserId = userId;
          }
          
          // 统一转换为下划线格式，保持与前端其他代码一致
          return {
            'id': user['id'],
            'username': user['username'],
            'email': user['email'],
            'real_name': user['realName'], // 转换小驼峰为下划线
            'phone': user['phone'],
            'position': user['position'],
          'avatar_url': avatarUrl, // 转换小驼峰为下划线
          'created_at': user['createdAt'] ?? user['created_at'],
          };
        }
      }
    } catch (e) {
      print('获取用户信息失败: $e');
    }
    return null;
  }
  
  // 缓存头像图片（解码 base64 字符串）- 内部方法
  static void _cacheAvatarImage(String avatarUrl) {
    try {
      if (avatarUrl.startsWith('data:')) {
        // data URI 格式：data:[<mediatype>][;base64],<data>
        final parts = avatarUrl.split(',');
        if (parts.length >= 2) {
          final base64String = parts[1];
          final imageBytes = base64Decode(base64String);
          _cachedAvatarImage = MemoryImage(imageBytes);
          _cachedAvatarUrl = avatarUrl;
        }
      }
    } catch (e) {
      print('缓存头像失败: $e');
      _cachedAvatarImage = null;
      _cachedAvatarUrl = null;
    }
  }
  
  // 获取缓存的头像 ImageProvider
  static ImageProvider? getCachedAvatarImage(String? avatarUrl) {
    // 如果头像URL与缓存的一致，返回缓存的图片
    if (avatarUrl != null && avatarUrl == _cachedAvatarUrl && _cachedAvatarImage != null) {
      return _cachedAvatarImage;
    }
    return null;
  }
  
  // 更新头像缓存（外部调用，用于手动更新缓存）
  static void updateAvatarCache(String avatarUrl, ImageProvider imageProvider) {
    _cachedAvatarImage = imageProvider;
    _cachedAvatarUrl = avatarUrl;
  }
  
  // 清除头像缓存（退出登录时调用）
  static void clearAvatarCache() {
    _cachedAvatarImage = null;
    _cachedAvatarUrl = null;
    _cachedUserId = null;
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

  // 上传头像
  Future<bool> uploadAvatar(File imageFile) async {
    try {
      final String? token = await _getToken();
      if (token == null) return false;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/user/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('avatar', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // 上传成功后，更新头像缓存
        if (data['success'] == true && data['avatarUrl'] != null) {
          final newAvatarUrl = data['avatarUrl'] as String;
          _cacheAvatarImage(newAvatarUrl);
        }
        
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('上传头像失败: $e');
      return false;
    }
  }
}
