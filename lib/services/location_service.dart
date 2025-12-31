import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../config/server_config.dart';

class LocationService {
  /// 检查并请求位置权限
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// 获取当前位置信息（包括经纬度和地址）
  Future<Map<String, dynamic>?> getCurrentLocation() async {
    try {
      // 权限检查
      if (!await checkAndRequestPermission()) return null;

      // 获取当前位置（加入超时防止卡住）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).timeout(const Duration(seconds: 15));

      String? address;

      // 检测是否为 Web 或 Windows 平台，跳过本地 geocoding
      final isWebOrWindows = kIsWeb || (!kIsWeb && Platform.isWindows);

      // 仅在 Android/iOS 平台使用本地 geocoding 插件
      if (!isWebOrWindows) {
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = <String>[];
            void add(String? value, {bool excludeChina = false}) {
              final v = value?.trim();
              if (v == null || v.isEmpty) return;
              if (excludeChina && v == '中国') return;
              if (!parts.contains(v)) parts.add(v);
            }
            add(p.country, excludeChina: true);
            add(p.administrativeArea);
            add(p.locality);
            add(p.subLocality);
            add(p.thoroughfare);
            add(p.subThoroughfare);
            add(p.street);
            add(p.name);
            final joined = parts.where((e) => e.trim().isNotEmpty).join('');
            if (joined.isNotEmpty) address = joined;
          }
        } catch (e, st) {
          print('反向地理编码(本地)失败: $e');
          print(st);
        }
      }

      // 若本地失败或跳过，调用后端高德地图接口
      if (address == null) {
        try {
          final baseUrl = await ServerConfig.getBaseUrl();
          final url = Uri.parse(
              '$baseUrl/geocode?lat=${position.latitude}&lon=${position.longitude}');
          final resp = await http.get(url).timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data['success'] == true && data['address'] != null) {
              address = data['address'];
            }
          } else {
            print('后端逆地理编码响应非200: ${resp.statusCode}');
          }
        } catch (e) {
          print('后端逆地理编码失败: $e');
        }
      }

      // 若无法获取有效地址，返回 null（不存储到数据库）
      if (address == null || address.isEmpty) {
        print('无法解析地址，取消位置信息获取');
        return null;
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
    } catch (e) {
      print('获取位置失败: $e');
      return null;
    }
  }

  /// 打开系统位置设置页面
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  /// 打开应用设置页面（用于永久拒绝权限的情况）
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }
}
