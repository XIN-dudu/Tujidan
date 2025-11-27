import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_item.dart';

class NotificationService {
  static const String _tokenKey = 'auth_token';
  static const String _baseUrl = 'http://127.0.0.1:3001/api';

  static Future<String?> _getToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// 从后端API获取所有通知
  static Future<List<NotificationItem>> getNotifications() async {
    final token = await _getToken();
    if (token == null) {
      // 用户未登录，返回空列表
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(utf8.decode(response.bodyBytes));
        if (body['success'] == true && body['data'] != null) {
          final List<dynamic> notificationsJson = body['data'];
          return notificationsJson
              .map((json) => NotificationItem.fromJson(json))
              .toList();
        }
      } else {
        // 可以根据需要处理不同的错误状态码
        print('获取通知失败: ${response.statusCode}');
      }
    } catch (e) {
      print('获取通知异常: $e');
    }

    return []; // 出错时返回空列表
  }

  /// 标记所有通知为已读
  static Future<bool> markAllAsRead() async {
    final token = await _getToken();
    if (token == null) {
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/notifications/mark-as-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      } else {
        print('标记已读失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('标记已读异常: $e');
      return false;
    }
  }

  /// 删除指定ID的通知
  static Future<bool> deleteNotification(String notificationId) async {
    final token = await _getToken();
    if (token == null) {
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/notifications/$notificationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        return body['success'] == true;
      } else {
        print('删除通知失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('删除通知异常: $e');
      return false;
    }
  }
}