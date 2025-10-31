import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../services/log_service.dart';

enum ViewType { month, week, day }

class LogViewPage extends StatefulWidget {
  final LogEntry? logEntry; // 要查看的日志

  const LogViewPage({super.key, this.logEntry});

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  ViewType _currentView = ViewType.month;
  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate; // 选中的日期
  List<LogEntry> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.logEntry != null) {
      // 如果传入了具体日志，设置日期并加载对应日期的日志
      _selectedDate = widget.logEntry!.time;
      _currentDate = widget.logEntry!.time;
      _loadLogById(widget.logEntry!.id);
    } else {
      // 否则加载当前日期的日志
      _selectedDate = DateTime.now();
      _loadLogs();
    }
  }

  Future<void> _loadLogById(String logId) async {
    setState(() => _isLoading = true);
    try {
      final response = await LogService.getLogById(logId);
      if (response.success && response.data != null) {
        setState(() {
          _logs = [response.data!];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载日志失败: ${response.message}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: $e')),
        );
      }
    }
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      DateTime startDate, endDate;
      
      switch (_currentView) {
        case ViewType.month:
          startDate = DateTime(_currentDate.year, _currentDate.month, 1);
          endDate = DateTime(_currentDate.year, _currentDate.month + 1, 0);
          break;
        case ViewType.week:
          final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
          startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
          endDate = startDate.add(const Duration(days: 6));
          break;
        case ViewType.day:
          startDate = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
          endDate = startDate.add(const Duration(days: 1));
          break;
      }

      final response = await LogService.getLogsFiltered(
        startTime: startDate,
        endTime: endDate,
      );

      if (response.success && response.data != null) {
        setState(() {
          _logs = response.data!;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载日志失败: ${response.message}')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: $e')),
        );
      }
    }
  }

  void _changeView(ViewType view) {
    setState(() {
      _currentView = view;
    });
    _loadLogs();
  }

  void _navigateDate(int direction) {
    setState(() {
      switch (_currentView) {
        case ViewType.month:
          _currentDate = DateTime(_currentDate.year, _currentDate.month + direction, 1);
          break;
        case ViewType.week:
          _currentDate = _currentDate.add(Duration(days: direction * 7));
          break;
        case ViewType.day:
          _currentDate = _currentDate.add(Duration(days: direction));
          break;
      }
    });
    _loadLogs();
  }

  Future<void> _pickDate() async {
    final initial = DateTime(_currentDate.year, _currentDate.month, _currentDate.day);
    final first = DateTime(1900, 1, 1);
    final last = DateTime(2100, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (picked != null) {
      setState(() {
        _currentDate = picked;
        _selectedDate = picked;
      });
      _loadLogs();
    }
  }


  String _getViewTitle() {
    switch (_currentView) {
      case ViewType.month:
        return '${_currentDate.year}年${_currentDate.month}月';
      case ViewType.week:
        final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        return '${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}';
      case ViewType.day:
        return '${_currentDate.year}年${_currentDate.month}月${_currentDate.day}日';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        title: GestureDetector(
          onTap: _pickDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_getViewTitle()),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 视图切换和日期导航
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 视图切换按钮
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildViewButton('月视图', ViewType.month, Icons.calendar_month),
                            _buildViewButton('周视图', ViewType.week, Icons.view_week),
                            _buildViewButton('日视图', ViewType.day, Icons.today),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 日期导航
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () => _navigateDate(-1),
                            ),
                            Text(
                              _getViewTitle(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => _navigateDate(1),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // 内容区域
                  _buildViewContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildViewButton(String title, ViewType view, IconData icon) {
    final isSelected = _currentView == view;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton.icon(
          onPressed: () => _changeView(view),
          icon: Icon(icon, size: 18),
          label: Text(title, style: const TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey[200],
            foregroundColor: isSelected ? Colors.white : Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildViewContent() {
    switch (_currentView) {
      case ViewType.month:
        return _buildMonthView();
      case ViewType.week:
        return _buildWeekView();
      case ViewType.day:
        return _buildDayView();
    }
  }

  Widget _buildMonthView() {
    final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
    final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);
    final firstWeekday = firstDay.weekday;
    final daysInMonth = lastDay.day;
    
    // 创建日历网格
    List<Widget> calendarCells = [];
    
    // 添加星期标题
    final weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    for (String day in weekdays) {
      calendarCells.add(
        Container(
          height: 40,
          alignment: Alignment.center,
          child: Text(
            day,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      );
    }
    
    // 添加空白单元格（月初前的空白）
    for (int i = 1; i < firstWeekday; i++) {
      calendarCells.add(const SizedBox(height: 60));
    }
    
    // 添加日期单元格
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentDate.year, _currentDate.month, day);
      final dayLogs = _logs.where((log) => 
        log.time.year == date.year && 
        log.time.month == date.month && 
        log.time.day == date.day
      ).toList();
      
      calendarCells.add(_buildCalendarCell(day, dayLogs, date));
    }
    
    return Column(
      children: [
        // 日历网格
        GridView.builder(
          padding: const EdgeInsets.all(16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.2,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: calendarCells.length,
          itemBuilder: (context, index) => calendarCells[index],
        ),
        // 选中日期的日志详情
        _buildSelectedDateLogs(),
      ],
    );
  }

  Widget _buildCalendarCell(int day, List<LogEntry> dayLogs, DateTime date) {
    final isToday = date.day == DateTime.now().day && 
                   date.month == DateTime.now().month && 
                   date.year == DateTime.now().year;
    final isSelected = _selectedDate != null &&
                      _selectedDate!.day == date.day &&
                      _selectedDate!.month == date.month &&
                      _selectedDate!.year == date.year;
    
    // 获取该日期的最高优先级日志
    TaskPriority? highestPriority;
    if (dayLogs.isNotEmpty) {
      highestPriority = dayLogs.map((log) => log.priority).reduce((a, b) {
        if (a == TaskPriority.high || b == TaskPriority.high) return TaskPriority.high;
        if (a == TaskPriority.medium || b == TaskPriority.medium) return TaskPriority.medium;
        return TaskPriority.low;
      });
    }
    
    // 定义不同的样式
    Color backgroundColor;
    Color borderColor;
    double borderWidth;
    FontWeight fontWeight;
    Color textColor;
    
    if (isSelected) {
      // 选中状态：明显的主题色
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.2);
      borderColor = Theme.of(context).colorScheme.primary;
      borderWidth = 2;
      fontWeight = FontWeight.bold;
      textColor = Theme.of(context).colorScheme.primary;
    } else if (isToday && _selectedDate == null) {
      // 今天状态：只有在没有选中其他日期时才高亮
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.1);
      borderColor = Theme.of(context).colorScheme.primary;
      borderWidth = 2;
      fontWeight = FontWeight.bold;
      textColor = Theme.of(context).colorScheme.primary;
    } else {
      // 普通状态
      backgroundColor = Colors.white;
      borderColor = Colors.grey[300]!;
      borderWidth = 1;
      fontWeight = FontWeight.normal;
      textColor = Colors.black87;
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDate = date;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: Stack(
          children: [
            // 日期数字
            Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontWeight: fontWeight,
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ),
            // 优先级圆点 - 固定在右下角
            if (highestPriority != null)
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getPriorityColor(highestPriority),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView() {
    final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    
    return Column(
      children: weekDays.map((day) {
        final dayLogs = _logs.where((log) => 
          log.time.year == day.year && 
          log.time.month == day.month && 
          log.time.day == day.day
        ).toList();
        
        return _buildWeekDayCard(day, dayLogs);
      }).toList(),
    );
  }

  Widget _buildWeekDayCard(DateTime day, List<LogEntry> dayLogs) {
    final isToday = day.day == DateTime.now().day && 
                   day.month == DateTime.now().month && 
                   day.year == DateTime.now().year;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isToday ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${day.month}/${day.day}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Theme.of(context).colorScheme.primary : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _getWeekdayName(day.weekday),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${dayLogs.length}条日志',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (dayLogs.isEmpty)
              const Text(
                '暂无日志',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              )
            else
              ...dayLogs.map((log) => _buildLogItem(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayView() {
    final dayLogs = _logs.where((log) => 
      log.time.year == _currentDate.year && 
      log.time.month == _currentDate.month && 
      log.time.day == _currentDate.day
    ).toList();
    
    if (dayLogs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '今日暂无日志',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: dayLogs.map((log) => _buildLogItem(log)).toList(),
    );
  }

  Widget _buildLogItem(LogEntry log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          width: 4,
          color: _getPriorityColor(log.priority),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (log.title.isNotEmpty ? log.title : log.content),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 状态指示器
                    Icon(
                      log.logStatus == 'completed' 
                        ? Icons.check_circle 
                        : log.logStatus == 'cancelled'
                          ? Icons.cancel
                          : Icons.radio_button_unchecked,
                      size: 14,
                      color: log.logStatus == 'completed' 
                        ? Colors.green 
                        : log.logStatus == 'cancelled'
                          ? Colors.red
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.logStatus == 'completed' 
                        ? '已完成' 
                        : log.logStatus == 'cancelled'
                          ? '已取消'
                          : '进行中',
                      style: TextStyle(
                        fontSize: 12,
                        color: log.logStatus == 'completed' 
                          ? Colors.green 
                          : log.logStatus == 'cancelled'
                            ? Colors.red
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (log.type != null) ...[
                      Icon(Icons.label, size: 14, color: Colors.blueGrey[700]),
                      const SizedBox(width: 4),
                      Text(
                        log.type!,
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.flag, size: 14, color: _getPriorityColor(log.priority)),
                    const SizedBox(width: 4),
                    Text(
                      log.priority.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: _getPriorityColor(log.priority),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[weekday - 1];
  }

  Widget _buildSelectedDateLogs() {

    final selectedDateLogs = _logs.where((log) => 
      log.time.year == _selectedDate!.year && 
      log.time.month == _selectedDate!.month && 
      log.time.day == _selectedDate!.day
    ).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 选中日期标题
          Row(
            children: [
              Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${selectedDateLogs.length}条日志',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 日志列表
          selectedDateLogs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        '该日期暂无日志',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: selectedDateLogs.map((log) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getPriorityColor(log.priority).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getPriorityColor(log.priority),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (log.title.isNotEmpty ? log.title : log.content),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (log.type != null) ...[
                                      Icon(Icons.label, size: 14, color: Colors.blueGrey[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        log.type!,
                                        style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(Icons.flag, size: 14, color: _getPriorityColor(log.priority)),
                                    const SizedBox(width: 4),
                                    Text(
                                      log.priority.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getPriorityColor(log.priority),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}
