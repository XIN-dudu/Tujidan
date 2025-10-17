import 'package:flutter/material.dart';

class YearPickerPage extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const YearPickerPage({
    super.key,
    required this.initialDate,
    required this.onDateSelected,
  });

  @override
  State<YearPickerPage> createState() => _YearPickerPageState();
}

class _YearPickerPageState extends State<YearPickerPage> {
  late DateTime _selectedDate;
  late ScrollController _scrollController;

  // 年份范围（足够大，近似“无限”）
  static const int _startYear = 1900;
  static const int _endYear = 2100;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _scrollController = ScrollController();

    // 等待首帧后滚动到当前年份附近
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetIndex = (_selectedDate.year - _startYear).clamp(0, _endYear - _startYear);
      // 预估每个年份块高度（标题+网格），用于跳转位置。这里使用经验高度 560。
      _scrollController.jumpTo(targetIndex * 560.0);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onMonthSelected(int year, int month) {
    final selectedDate = DateTime(year, month, 1);
    widget.onDateSelected(selectedDate);
    Navigator.of(context).pop();
  }

  Widget _buildMiniMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final firstWeekday = firstDay.weekday; // 1..7
    final daysInMonth = lastDay.day;

    // 构建日期小网格（7列，至多6行）
    final List<Widget> cells = [];
    // 月份标题
    cells.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          '$month月',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );

    // 星期占位（可选：简洁起见不显示，保持紧凑）

    // 前置空白
    int leading = firstWeekday - 1; // 以周一为起点
    for (int i = 0; i < leading; i++) {
      cells.add(const SizedBox(height: 16));
    }
    // 日期数字
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(
        SizedBox(
          height: 16,
          child: Text(
            '$d',
            style: const TextStyle(fontSize: 11, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 包装为7列的网格
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _onMonthSelected(year, month),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (year == _selectedDate.year && month == _selectedDate.month)
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: (year == _selectedDate.year && month == _selectedDate.month) ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ),
    );
  }

  Widget _buildYearBlock(int year) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '$year年',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 12,
            itemBuilder: (context, index) => _buildMiniMonth(year, index + 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearsCount = _endYear - _startYear + 1;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('选择年月'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              widget.onDateSelected(DateTime.now());
              Navigator.of(context).pop();
            },
            child: const Text('今天'),
          ),
        ],
      ),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: yearsCount,
        itemBuilder: (context, index) {
          final year = _startYear + index;
          return _buildYearBlock(year);
        },
      ),
    );
  }
}
