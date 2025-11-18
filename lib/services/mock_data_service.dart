import '../models/task.dart';
import '../models/log_entry.dart';

class MockDataService {
  static final List<Task> _mockTasks = [
    Task(
      id: '1',
      name: '完成项目文档',
      description: '编写项目需求文档和技术规格说明',
      assignee: '张三',
      creator: '1', // 模拟创建者ID
      deadline: DateTime.now().add(const Duration(days: 7)),
      priority: TaskPriority.high,
      status: TaskStatus.in_progress,
      progress: 60,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Task(
      id: '2',
      name: '代码审查',
      description: '对团队成员提交的代码进行审查',
      assignee: '李四',
      creator: '1', // 模拟创建者ID
      deadline: DateTime.now().add(const Duration(days: 3)),
      priority: TaskPriority.medium,
      status: TaskStatus.not_started,
      progress: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Task(
      id: '3',
      name: '用户界面设计',
      description: '设计新的用户界面原型',
      assignee: '王五',
      creator: '2', // 模拟创建者ID
      deadline: DateTime.now().add(const Duration(days: 10)),
      priority: TaskPriority.low,
      status: TaskStatus.completed,
      progress: 100,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Task(
      id: '4',
      name: '数据库优化',
      description: '优化数据库查询性能',
      assignee: '赵六',
      creator: '1', // 模拟创建者ID
      deadline: DateTime.now().add(const Duration(days: 5)),
      priority: TaskPriority.high,
      status: TaskStatus.in_progress,
      progress: 30,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  static final List<LogEntry> _mockLogs = [
    LogEntry(
      id: '1',
      title: '完成了项目文档的第一章节',
      content: '完成了项目文档的第一章节',
      taskId: '1',
      priority: TaskPriority.high,
      time: DateTime.now().subtract(const Duration(hours: 2)),
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    LogEntry(
      id: '2',
      title: '开始进行代码审查工作',
      content: '开始进行代码审查工作',
      taskId: '2',
      priority: TaskPriority.medium,
      time: DateTime.now().subtract(const Duration(hours: 4)),
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    LogEntry(
      id: '3',
      title: '今天的日常工作总结',
      content: '今天的日常工作总结',
      priority: TaskPriority.low,
      time: DateTime.now().subtract(const Duration(hours: 6)),
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
  ];

  // ------------------- Task Methods -------------------
  static Future<List<Task>> getTasks() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockTasks);
  }

  static Future<Task?> getTaskById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockTasks.firstWhere((task) => task.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<List<Task>> getTasksByAssignee(String assignee) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockTasks.where((task) => task.assignee == assignee).toList();
  }

  static Future<Task> createTask(Task task) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final newTask = task.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockTasks.add(newTask);
    return newTask;
  }

  static Future<Task> updateTask(Task task) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockTasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _mockTasks[index] = task.copyWith(updatedAt: DateTime.now());
      return _mockTasks[index];
    }
    throw Exception('任务不存在');
  }

  static Future<void> deleteTask(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockTasks.removeWhere((task) => task.id == id);
  }

  // ------------------- LogEntry Methods -------------------
  static Future<List<LogEntry>> getLogs() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_mockLogs);
  }

  static Future<LogEntry?> getLogById(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockLogs.firstWhere((log) => log.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<List<LogEntry>> getLogsByTaskId(String taskId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _mockLogs.where((log) => log.taskId == taskId).toList();
  }

  static Future<LogEntry> createLog(LogEntry log) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final newLog = log.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _mockLogs.add(newLog);
    return newLog;
  }

  static Future<LogEntry> updateLog(LogEntry log) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final index = _mockLogs.indexWhere((l) => l.id == log.id);
    if (index != -1) {
      _mockLogs[index] = log.copyWith(updatedAt: DateTime.now());
      return _mockLogs[index];
    }
    throw Exception('日志不存在');
  }

  static Future<void> deleteLog(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockLogs.removeWhere((log) => log.id == id);
  }

  static Future<List<LogEntry>> getLogsByDateRange(DateTime startDate, DateTime endDate) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockLogs.where((log) =>
    log.time.isAfter(startDate.subtract(const Duration(seconds: 1))) &&
        log.time.isBefore(endDate.add(const Duration(seconds: 1)))
    ).toList();
  }
}