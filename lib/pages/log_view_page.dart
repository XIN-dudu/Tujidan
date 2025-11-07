import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../services/log_service.dart';
import '../services/task_service.dart';

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
  List<Task> _tasks = [];
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

      final logResp = await LogService.getLogsFiltered(
        startTime: startDate,
        endTime: endDate,
      );
      final taskResp = await TaskService.getTasks();

      if (mounted) {
        setState(() {
          _logs = logResp.success && logResp.data != null ? logResp.data! : [];
          _tasks = taskResp.success && taskResp.data != null ? taskResp.data! : [];
          _isLoading = false;
        });
      }
      if (!logResp.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: ${logResp.message}')),
        );
      }
      if (!taskResp.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载任务失败: ${taskResp.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  _getViewTitle(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
            tooltip: '刷新',
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey[100],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // 视图切换和日期导航
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        // 视图切换按钮
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              _buildViewButton('月视图', ViewType.month, Icons.calendar_month_rounded),
                              _buildViewButton('周视图', ViewType.week, Icons.view_week_rounded),
                              _buildViewButton('日视图', ViewType.day, Icons.today_rounded),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 日期导航
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                                onPressed: () => _navigateDate(-1),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              Text(
                                _getViewTitle(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                                onPressed: () => _navigateDate(1),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
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
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _changeView(view),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[600],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
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
      final dayTasks = _tasks.where((task) =>
        task.deadline.year == date.year &&
        task.deadline.month == date.month &&
        task.deadline.day == date.day
      ).toList();
      calendarCells.add(_buildCalendarCell(day, dayLogs, date, dayTasks));
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

  Widget _buildCalendarCell(int day, List<LogEntry> dayLogs, DateTime date, List<Task> dayTasks) {
    final isToday = date.day == DateTime.now().day && 
                   date.month == DateTime.now().month && 
                   date.year == DateTime.now().year;
    final isSelected = _selectedDate != null &&
                      _selectedDate!.day == date.day &&
                      _selectedDate!.month == date.month &&
                      _selectedDate!.year == date.year;
    
    // 获取该日期的最高优先级日志或任务
    TaskPriority? highestPriority;
    final priorities = [
      ...dayLogs.map((log) => log.priority),
      ...dayTasks.map((task) => task.priority),
    ];
    if (priorities.isNotEmpty) {
      highestPriority = priorities.reduce((a, b) {
        if (a == TaskPriority.high || b == TaskPriority.high) return TaskPriority.high;
        if (a == TaskPriority.medium || b == TaskPriority.medium) return TaskPriority.medium;
        return TaskPriority.low;
      });
    }
    
    final hasContent = dayLogs.isNotEmpty || dayTasks.isNotEmpty;
    
    // 定义不同的样式
    Color backgroundColor;
    Color? borderColor;
    double borderWidth;
    FontWeight fontWeight;
    Color textColor;
    BoxShadow? shadow;
    
    if (isSelected) {
      // 选中状态：明显的主题色
      backgroundColor = Theme.of(context).colorScheme.primary;
      borderColor = null;
      borderWidth = 0;
      fontWeight = FontWeight.bold;
      textColor = Colors.white;
      shadow = BoxShadow(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );
    } else if (isToday) {
      // 今天状态
      backgroundColor = Theme.of(context).colorScheme.primary.withOpacity(0.15);
      borderColor = Theme.of(context).colorScheme.primary;
      borderWidth = 2;
      fontWeight = FontWeight.bold;
      textColor = Theme.of(context).colorScheme.primary;
      shadow = null;
    } else if (hasContent) {
      // 有内容的日期
      backgroundColor = Colors.white;
      borderColor = Colors.grey[300];
      borderWidth = 1;
      fontWeight = FontWeight.w500;
      textColor = Colors.black87;
      shadow = BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 4,
        offset: const Offset(0, 1),
      );
    } else {
      // 普通状态
      backgroundColor = Colors.grey[50]!;
      borderColor = Colors.grey[200];
      borderWidth = 1;
      fontWeight = FontWeight.normal;
      textColor = Colors.grey[600]!;
      shadow = null;
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
          borderRadius: BorderRadius.circular(10),
          border: borderColor != null ? Border.all(
            color: borderColor,
            width: borderWidth,
          ) : null,
          boxShadow: shadow != null ? [shadow] : null,
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
            // 内容指示器
            if (hasContent && !isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: highestPriority != null 
                      ? _getPriorityColor(highestPriority) 
                      : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // 任务数量指示 - 仅在有任务时显示
            if (dayTasks.isNotEmpty && !isSelected)
              Positioned(
                bottom: 2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dayTasks.length}',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
        final dayTasks = _tasks.where((task) =>
          task.deadline.year == day.year &&
          task.deadline.month == day.month &&
          task.deadline.day == day.day
        ).toList();
        
        return _buildWeekDayCard(day, dayLogs, dayTasks);
      }).toList(),
    );
  }

  Widget _buildWeekDayCard(DateTime day, List<LogEntry> dayLogs, List<Task> dayTasks) {
    final isToday = day.day == DateTime.now().day && 
                   day.month == DateTime.now().month && 
                   day.year == DateTime.now().year;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: isToday ? Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isToday 
                      ? Theme.of(context).colorScheme.primary 
                      : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${day.month}/${day.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isToday 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.black87,
                      ),
                    ),
                    Text(
                      _getWeekdayName(day.weekday),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_rounded, size: 14, color: Colors.purple[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${dayLogs.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.task_alt_rounded, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            '${dayTasks.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (dayLogs.isNotEmpty || dayTasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
            ],
            if (dayLogs.isEmpty && dayTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    '暂无日志与任务',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else ...[
              if (dayLogs.isNotEmpty) ...dayLogs.map((log) => _buildLogItem(log)),
              if (dayTasks.isNotEmpty) ...[
                if (dayLogs.isNotEmpty) const SizedBox(height: 8),
                ...dayTasks.map((task) => _buildTaskItem(task)),
              ],
            ],
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
    final dayTasks = _tasks.where((task) =>
      task.deadline.year == _currentDate.year &&
      task.deadline.month == _currentDate.month &&
      task.deadline.day == _currentDate.day
    ).toList();
    
    if (dayLogs.isEmpty && dayTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_note_rounded,
                  size: 64,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '今日暂无日志与任务',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '开始记录您的工作吧',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (dayLogs.isNotEmpty) ...[
            _buildSectionHeader('日志记录', dayLogs.length, Icons.article_rounded, Colors.purple),
            ...dayLogs.map((log) => _buildLogItem(log)),
          ],
          if (dayTasks.isNotEmpty) ...[
            if (dayLogs.isNotEmpty) const SizedBox(height: 16),
            _buildSectionHeader('任务列表', dayTasks.length, Icons.task_alt_rounded, Colors.blue),
            ...dayTasks.map((task) => _buildTaskItem(task)),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case TaskStatus.cancelled:
      case TaskStatus.closed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      case TaskStatus.paused:
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle_filled_rounded;
        break;
      case TaskStatus.in_progress:
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse_rounded;
        break;
      case TaskStatus.not_started:
        statusColor = Colors.blueGrey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        break;
      case TaskStatus.pending_assignment:
        statusColor = Colors.purple;
        statusIcon = Icons.pending_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            width: 4,
            color: _getPriorityColor(task.priority),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.task_alt_rounded, size: 12, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        '任务',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.name.isNotEmpty ? task.name : task.description,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildInfoChip(
                  icon: statusIcon,
                  label: task.status.displayName,
                  color: statusColor,
                ),
                _buildInfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${task.deadline.hour.toString().padLeft(2, '0')}:${task.deadline.minute.toString().padLeft(2, '0')}',
                  color: Colors.grey[600]!,
                ),
                _buildInfoChip(
                  icon: Icons.flag_rounded,
                  label: task.priority.displayName,
                  color: _getPriorityColor(task.priority),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildLogItem(LogEntry log) {
    Color statusColor;
    IconData statusIcon;
    
    if (log.logStatus == 'completed') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_rounded;
    } else if (log.logStatus == 'cancelled') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            width: 4,
            color: _getPriorityColor(log.priority),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.article_rounded, size: 12, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Text(
                        '日志',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (log.title.isNotEmpty ? log.title : log.content),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _buildInfoChip(
                  icon: statusIcon,
                  label: log.logStatus == 'completed' 
                    ? '已完成' 
                    : log.logStatus == 'cancelled'
                      ? '已取消'
                      : '进行中',
                  color: statusColor,
                ),
                if (log.type != null)
                  _buildInfoChip(
                    icon: Icons.label_rounded,
                    label: log.type!,
                    color: Colors.blueGrey[700]!,
                  ),
                _buildInfoChip(
                  icon: Icons.schedule_rounded,
                  label: '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                  color: Colors.grey[600]!,
                ),
                _buildInfoChip(
                  icon: Icons.flag_rounded,
                  label: log.priority.displayName,
                  color: _getPriorityColor(log.priority),
                ),
              ],
            ),
          ],
        ),
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

    final selectedDateTasks = _tasks.where((task) =>
      task.deadline.year == _selectedDate!.year &&
      task.deadline.month == _selectedDate!.month &&
      task.deadline.day == _selectedDate!.day
    ).toList();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, -3),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedDate!.year}年${_selectedDate!.month}月${_selectedDate!.day}日',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    _getWeekdayName(_selectedDate!.weekday),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${selectedDateLogs.length + selectedDateTasks.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // 日志和任务列表
          (selectedDateLogs.isEmpty && selectedDateTasks.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.event_note_rounded,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '该日期暂无内容',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '选择其他日期查看内容',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 日志部分
                    if (selectedDateLogs.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.article_rounded, size: 16, color: Colors.purple[700]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '日志记录',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                selectedDateLogs.length.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...selectedDateLogs.map((log) {
                        Color statusColor;
                        IconData statusIcon;
                        
                        if (log.logStatus == 'completed') {
                          statusColor = Colors.green;
                          statusIcon = Icons.check_circle_rounded;
                        } else if (log.logStatus == 'cancelled') {
                          statusColor = Colors.red;
                          statusIcon = Icons.cancel_rounded;
                        } else {
                          statusColor = Colors.orange;
                          statusIcon = Icons.radio_button_unchecked_rounded;
                        }

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getPriorityColor(log.priority).withOpacity(0.05),
                                Colors.white,
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border(
                              left: BorderSide(
                                color: _getPriorityColor(log.priority),
                                width: 4,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (log.title.isNotEmpty ? log.title : log.content),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  _buildInfoChip(
                                    icon: statusIcon,
                                    label: log.logStatus == 'completed' 
                                      ? '已完成' 
                                      : log.logStatus == 'cancelled'
                                        ? '已取消'
                                        : '进行中',
                                    color: statusColor,
                                  ),
                                  if (log.type != null)
                                    _buildInfoChip(
                                      icon: Icons.label_rounded,
                                      label: log.type!,
                                      color: Colors.blueGrey[700]!,
                                    ),
                                  _buildInfoChip(
                                    icon: Icons.schedule_rounded,
                                    label: '${log.time.hour.toString().padLeft(2, '0')}:${log.time.minute.toString().padLeft(2, '0')}',
                                    color: Colors.grey[600]!,
                                  ),
                                  _buildInfoChip(
                                    icon: Icons.flag_rounded,
                                    label: log.priority.displayName,
                                    color: _getPriorityColor(log.priority),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                    // 任务部分
                    if (selectedDateTasks.isNotEmpty) ...[
                      if (selectedDateLogs.isNotEmpty) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(Icons.task_alt_rounded, size: 16, color: Colors.blue[700]),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '任务列表',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                selectedDateTasks.length.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...selectedDateTasks.map((task) => _buildTaskItemCompact(task)).toList(),
                    ],
                  ],
                ),
        ],
      ),
    );
  }

  // 紧凑版任务卡片（用于月视图选中日期详情）
  Widget _buildTaskItemCompact(Task task) {
    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case TaskStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        break;
      case TaskStatus.cancelled:
      case TaskStatus.closed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        break;
      case TaskStatus.paused:
        statusColor = Colors.grey;
        statusIcon = Icons.pause_circle_filled_rounded;
        break;
      case TaskStatus.in_progress:
        statusColor = Colors.orange;
        statusIcon = Icons.timelapse_rounded;
        break;
      case TaskStatus.not_started:
        statusColor = Colors.blueGrey;
        statusIcon = Icons.radio_button_unchecked_rounded;
        break;
      case TaskStatus.pending_assignment:
        statusColor = Colors.purple;
        statusIcon = Icons.pending_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getPriorityColor(task.priority).withOpacity(0.05),
            Colors.white,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: _getPriorityColor(task.priority),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.name.isNotEmpty ? task.name : task.description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _buildInfoChip(
                icon: statusIcon,
                label: task.status.displayName,
                color: statusColor,
              ),
              _buildInfoChip(
                icon: Icons.schedule_rounded,
                label: '${task.deadline.hour.toString().padLeft(2, '0')}:${task.deadline.minute.toString().padLeft(2, '0')}',
                color: Colors.grey[600]!,
              ),
              _buildInfoChip(
                icon: Icons.flag_rounded,
                label: task.priority.displayName,
                color: _getPriorityColor(task.priority),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
