import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

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

      // 若本地失败或跳过，使用网络备用 Nominatim（开源，国内可能较慢）
      if (address == null) {
        try {
          final url = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1');
          final resp = await http.get(url, headers: {
            'User-Agent': 'TujidanApp/1.0 (reverse-geocode)',
            'Accept-Language': 'zh-CN'
          }).timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final display = data['display_name'];
            if (display is String && display.trim().isNotEmpty) {
              // OSM display_name 逗号分隔，取前若干段组合
              final segments = display.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              // 过滤国家名与重复项
              final filtered = <String>[];
              for (final s in segments) {
                if (s == '中国' || filtered.contains(s)) continue;
                filtered.add(s);
              }
              // 只取前 6 段避免过长
              address = filtered.take(6).join('');
            }
            // 若有分解 address 结构，可进一步优化
            final addrObj = data['address'];
            if (address == null && addrObj is Map) {
              final parts = <String>[];
              void addKey(String k) {
                final v = addrObj[k];
                if (v is String && v.trim().isNotEmpty && !parts.contains(v)) parts.add(v.trim());
              }
              // 常见字段顺序
              for (final k in [
                'state',
                'province',
                'city',
                'county',
                'district',
                'town',
                'suburb',
                'road',
                'residential',
                'hamlet',
                'neighbourhood',
                'house_number'
              ]) {
                addKey(k);
              }
              if (parts.isNotEmpty) address = parts.join('');
            }
          } else {
            print('Nominatim 响应非200: ${resp.statusCode}');
          }
        } catch (e) {
          print('网络备用逆地理失败: $e');
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
