import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

/// 日志活跃度趋势图（柱状图）
class LogActivityChart extends StatelessWidget {
  /// 每日日志数量统计
  final Map<DateTime, int> dailyCounts;

  const LogActivityChart({
    super.key,
    required this.dailyCounts,
  });

  @override
  Widget build(BuildContext context) {
    if (dailyCounts.isEmpty) {
      return const SizedBox.shrink(); // 如果没有数据，不显示任何内容
    }

    // 准备图表数据
    final barGroups = _prepareBarGroups();

    return Card(
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _calculateMaxY(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = dailyCounts.keys.elementAt(groupIndex);
                    final count = rod.toY.toInt();
                    return BarTooltipItem(
                      '${DateFormat.Md('zh_CN').format(day)}\n',
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$count 条',
                          style: const TextStyle(
                            color: Colors.yellow,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: _bottomTitles,
                    reservedSize: 38,
                  ),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return const FlLine(
                    color: Color(0xffe7e8ec),
                    strokeWidth: 1,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 准备柱状图的分组数据
  List<BarChartGroupData> _prepareBarGroups() {
    final sortedEntries = dailyCounts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: data.value.toDouble(),
            color: Colors.indigo,
            width: 16,
            borderRadius: BorderRadius.circular(AppTheme.radiusS),
            gradient: LinearGradient(
              colors: [
                Colors.indigo[400]!,
                Colors.indigo[600]!,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
        ],
      );
    }).toList();
  }

  // 计算Y轴最大值
  double _calculateMaxY() {
    final maxCount = dailyCounts.values.fold(0, (max, count) => count > max ? count : max);
    return (maxCount * 1.2).ceilToDouble(); // 增加20%的顶部空间
  }

  // 自定义底部标题（日期）
  Widget _bottomTitles(double value, TitleMeta meta) {
    final sortedKeys = dailyCounts.keys.toList()..sort();
    final index = value.toInt();

    String text;
    // 每隔几天显示一个标签，避免拥挤
    if (index % 5 == 0 && index < sortedKeys.length) {
      text = DateFormat.d('zh_CN').format(sortedKeys[index]);
    } else {
      text = '';
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16,
      child: Text(text),
    );
  }
}