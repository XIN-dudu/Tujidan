import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 日志类型分布饼图组件
class LogTypePieChart extends StatelessWidget {
  /// 各日志类型的数量统计
  final Map<String, int> typeCounts;

  /// 饼图的半径
  final double chartRadius;

  /// 是否在中心显示总数
  final bool showCenterTotal;

  const LogTypePieChart({
    super.key,
    required this.typeCounts,
    this.chartRadius = 100.0,
    this.showCenterTotal = true,
  });

  // 为不同日志类型定义固定的颜色
  static const Map<String, Color> _typeColors = {
    'work': Colors.blue,
    'study': Colors.green,
    'life': Colors.orange,
    'other': Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    // 计算总数
    final total = typeCounts.values.fold(0, (sum, count) => sum + count);

    // 如果没有数据，则显示提示信息
    if (total == 0) {
      return const Center(
        child: Text(
          '当前月份没有日志记录',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    // 构建饼图的各个部分
    final sections = _buildChartSections(total);

    return Column(
      children: [
        SizedBox(
          height: chartRadius * 2,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: chartRadius * 0.4, // 中心留白半径
                  sectionsSpace: 2, // 各扇区之间的间距
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      // 可在这里添加交互逻辑
                    },
                  ),
                ),
              ),
              if (showCenterTotal)
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('总计', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('$total', style: const TextStyle(fontSize: 20, color: Colors.black54)),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 构建图例
        _buildLegend(),
      ],
    );
  }

  /// 构建饼图的扇区
  List<PieChartSectionData> _buildChartSections(int total) {
    return typeCounts.entries
        .where((entry) => entry.value > 0)
        .map((entry) {
      final type = entry.key;
      final count = entry.value;
      final percentage = (count / total * 100).toStringAsFixed(1);
      final color = _typeColors[type] ?? Colors.purple; // 如果类型未知，使用紫色

      return PieChartSectionData(
        color: color,
        value: count.toDouble(),
        title: '$percentage%',
        radius: chartRadius * 0.5,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  /// 构建图例
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: typeCounts.entries
          .where((entry) => entry.value > 0)
          .map((entry) {
        final type = entry.key;
        final color = _typeColors[type] ?? Colors.purple;
        final translatedType = _translateType(type); // 类型中文转换

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(translatedType),
          ],
        );
      }).toList(),
    );
  }

  /// 将日志类型从英文转换为中文
  String _translateType(String type) {
    switch (type) {
      case 'work':
        return '工作';
      case 'study':
        return '学习';
      case 'life':
        return '生活';
      case 'other':
        return '其他';
      default:
        return type;
    }
  }
}