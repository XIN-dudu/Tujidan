import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../services/log_service.dart';

enum ViewType { month, week, day }

class LogViewPage extends StatefulWidget {
  const LogViewPage({super.key});

  @override
  State<LogViewPage> createState() => _LogViewPageState();
}

class _LogViewPageState extends State<LogViewPage> {
  ViewType _currentView = ViewType.month;
  DateTime _currentDate = DateTime.now();
  List<LogEntry> _logs = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
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

      final response = await LogService.getLogsByDateRange(startDate, endDate);
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
        title: Text(_getViewTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildViewContent(),
          ),
        ],
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
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: calendarCells.length,
      itemBuilder: (context, index) => calendarCells[index],
    );
  }

  Widget _buildCalendarCell(int day, List<LogEntry> dayLogs, DateTime date) {
    final isToday = date.day == DateTime.now().day && 
                   date.month == DateTime.now().month && 
                   date.year == DateTime.now().year;
    
    return Container(
      decoration: BoxDecoration(
        color: isToday ? Theme.of(context).colorScheme.primary.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey[300]!,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              day.toString(),
              style: TextStyle(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? Theme.of(context).colorScheme.primary : Colors.black87,
              ),
            ),
          ),
          if (dayLogs.isNotEmpty) ...[
            Expanded(
              child: ListView.builder(
                itemCount: dayLogs.length > 3 ? 3 : dayLogs.length,
                itemBuilder: (context, index) {
                  final log = dayLogs[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(log.priority).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      log.content,
                      style: const TextStyle(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
            if (dayLogs.length > 3)
              Text(
                '+${dayLogs.length - 3}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    final weekStart = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
    final weekDays = List.generate(7, (index) => weekStart.add(Duration(days: index)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = weekDays[index];
        final dayLogs = _logs.where((log) => 
          log.time.year == day.year && 
          log.time.month == day.month && 
          log.time.day == day.day
        ).toList();
        
        return _buildWeekDayCard(day, dayLogs);
      },
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
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayLogs.length,
      itemBuilder: (context, index) {
        final log = dayLogs[index];
        return _buildLogItem(log);
      },
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
                  log.content,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
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
}
