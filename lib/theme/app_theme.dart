import 'dart:io';
import 'package:flutter/material.dart';

/// 应用主题配置
class AppTheme {
  // 间距常量
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // 圆角常量
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 20.0;

  // 卡片样式
  static const double cardElevation = 2.0;
  static const double cardRadius = 16.0;

  // 按钮样式
  static const double buttonRadius = 12.0;
  static const double buttonHeight = 48.0;

  // 图标大小
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;

  // 颜色定义（使用主题色系统）
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  // 优先级颜色
  static Color getPriorityColorHigh() => Colors.red;
  static Color getPriorityColorMedium() => Colors.orange;
  static Color getPriorityColorLow() => Colors.green;

  // 状态颜色
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case '待处理':
        return Colors.grey;
      case 'in_progress':
      case 'inprogress':
      case 'ongoing':
      case 'active':
      case '进行中':
        return Colors.blue;
      case 'completed':
      case 'done':
      case 'finished':
      case '已完成':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
      case '已取消':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // 获取主题配置
  static ThemeData getTheme() {
    final String? fontFamily = Platform.isWindows ? "微软雅黑" : null;
    return ThemeData(
      useMaterial3: true,
      colorSchemeSeed: Colors.indigo,
      scaffoldBackgroundColor: const Color(0xFFF6F6FA),
      fontFamily: fontFamily,
      cardTheme: CardThemeData(
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          elevation: 0,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingL,
          vertical: spacingM,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
    );
  }
}

