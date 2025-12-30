import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:test_flutter/auth_service.dart';
import 'package:test_flutter/models/api_response.dart';
import 'package:test_flutter/login_page.dart';
import 'package:test_flutter/models/notification_item.dart';
import 'package:test_flutter/pages/log_edit_page.dart';
import 'package:test_flutter/pages/log_list_page.dart';
import 'package:test_flutter/pages/log_view_page.dart';
import 'package:test_flutter/pages/task_list_page.dart';
import 'package:test_flutter/pages/task_view_page.dart';
import 'package:test_flutter/pages/user_profile_page.dart';
import 'package:test_flutter/services/dashboard_service.dart';
import 'package:test_flutter/models/dashboard_log_item.dart';
import 'package:test_flutter/models/top_item.dart';
import 'package:test_flutter/models/dashboard_task_item.dart';
import 'package:test_flutter/models/log_entry.dart';
import 'package:test_flutter/models/task.dart';
import 'package:test_flutter/services/notification_service.dart';
import 'package:test_flutter/services/top_item_service.dart';
import 'package:test_flutter/services/log_service.dart';
import 'package:test_flutter/services/task_service.dart';
import 'package:test_flutter/services/user_service.dart';
import 'package:test_flutter/theme/app_theme.dart';

// 全局错误日志
String _errorLog = '';

Future<void> _saveErrorToFile(String error) async {
  try {
    // 保存到应用内部目录
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/error_log.txt');
    final timestamp = DateTime.now().toString();
    final logEntry = '[$timestamp] $error\n\n';
    await file.writeAsString(logEntry, mode: FileMode.append);
    
    // 同时打印到控制台（可以通过 adb logcat 查看）
    print('ERROR_LOG: $logEntry');
    
    // 尝试保存到外部存储（如果可用）
    try {
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final externalFile = File('${externalDir.path}/error_log.txt');
        await externalFile.writeAsString(logEntry, mode: FileMode.append);
        print('ERROR_LOG_SAVED_TO: ${externalFile.path}');
      }
    } catch (e) {
      print('保存到外部存储失败: $e');
    }
  } catch (e) {
    print('保存错误日志失败: $e');
  }
}

void main() async {
  // 使用 runZonedGuarded 捕获所有错误，包括同步错误
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // 捕获 Flutter 框架错误
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      final errorMsg = 'Flutter Error: ${details.exception}\nStack trace: ${details.stack}';
      print('========== FLUTTER ERROR ==========');
      print(errorMsg);
      print('===================================');
      _errorLog = errorMsg;
      _saveErrorToFile(errorMsg);
    };
    
    // 捕获 Dart 异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorMsg = 'Uncaught Error: $error\nStack trace: $stack';
      print('========== UNCAUGHT ERROR ==========');
      print(errorMsg);
      print('====================================');
      _errorLog = errorMsg;
      _saveErrorToFile(errorMsg);
      return true;
    };
    
    await initializeDateFormatting('zh_CN', null);
    runApp(const MyApp());
  }, (error, stack) {
    // 捕获所有未处理的错误
    final errorMsg = 'Zone Error: $error\nStack trace: $stack';
    print('========== ZONE ERROR ==========');
    print(errorMsg);
    print('================================');
    _errorLog = errorMsg;
    _saveErrorToFile(errorMsg);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '潘多拉',
      theme: AppTheme.getTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // 如果有错误，显示错误信息
        if (_errorLog.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('发生错误，请查看日志文件'),
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: '查看',
                    onPressed: () {
                      _showErrorDialog(context);
                    },
                  ),
                ),
              );
            }
          });
        }
        return child ?? const SizedBox();
      },
      home: _RootDecider(),
    );
  }
  
  void _showErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误信息'),
        content: SingleChildScrollView(
          child: Text(_errorLog.isEmpty ? '暂无错误' : _errorLog),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                final directory = await getApplicationDocumentsDirectory();
                final file = File('${directory.path}/error_log.txt');
                if (await file.exists()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('日志文件位置: ${file.path}'),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('获取日志路径失败: $e')),
                );
              }
              Navigator.of(context).pop();
            },
            child: const Text('查看日志文件路径'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    QuadrantPage(),
    const LogViewPage(),
    const LogListPage(),
    const TaskListPage(),
    const UserProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: '导图'),
          NavigationDestination(icon: Icon(Icons.view_module_outlined), selectedIcon: Icon(Icons.view_module), label: '视图'),
          NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: '日志'),
          NavigationDestination(icon: Icon(Icons.task_outlined), selectedIcon: Icon(Icons.task), label: '任务'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }
}

class QuadrantPage extends StatefulWidget {
  QuadrantPage({super.key});

  @override
  State<QuadrantPage> createState() => _QuadrantPageState();
}

class _QuadrantPageState extends State<QuadrantPage> {
  final DateFormat _dateFormat = DateFormat('MM-dd HH:mm');
  final DateFormat _topItemDateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final UserService _userService = UserService();
  String? _currentUserId;
  bool _loadingLogs = false;
  String? _logError;
  List<DashboardLogItem> _dashboardLogs = [];
  bool _hasUnread = false;

  bool _loadingTopItems = false;
  String? _topItemsError;
  List<TopItem> _topItems = [];
  bool _loadingCompanyTasks = false;
  String? _companyTaskError;
  List<DashboardTaskItem> _companyTasks = [];
  bool _loadingPersonalTopItems = false;
  String? _personalTopItemsError;
  List<TopItem> _personalTopItems = [];

  List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _ensureCurrentUserId();
    _loadDashboardLogs();
    _loadCompanyTasks();
    _loadTopItems();
    _loadPersonalTopItems();
    _refreshNotifications();
  }

  Future<void> _ensureCurrentUserId() async {
    if (_currentUserId != null) return;
    final user = await _userService.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?['id']?.toString();
    });
  }

  Future<void> _loadDashboardLogs({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loadingLogs = true;
        _logError = null;
      });
    }

    try {
      final response = await DashboardService.getDashboardLogs();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _dashboardLogs = response.data!;
          _loadingLogs = false;
          _logError = null;
        });
      } else {
        setState(() {
          _loadingLogs = false;
          _logError = response.message.isNotEmpty ? response.message : '加载失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('加载日志失败: $e');
      setState(() {
        _loadingLogs = false;
        _logError = '加载失败: $e';
      });
    }
  }

  Future<void> _loadTopItems() async {
    setState(() {
      _loadingTopItems = true;
      _topItemsError = null;
    });

    final response = await TopItemService.getTopItems(limit: 10);
    if (!mounted) return;
    if (response.success && response.data != null) {
      setState(() {
        _topItems = response.data!;
        _loadingTopItems = false;
      });
    } else {
      setState(() {
        _loadingTopItems = false;
        _topItemsError = response.message.isNotEmpty ? response.message : '加载失败';
      });
    }
  }

  Future<void> _loadPersonalTopItems() async {
    setState(() {
      _loadingPersonalTopItems = true;
      _personalTopItemsError = null;
    });

    final response = await TopItemService.getPersonalTopItems(limit: 10);
    if (!mounted) return;
    if (response.success && response.data != null) {
      setState(() {
        _personalTopItems = response.data!;
        _loadingPersonalTopItems = false;
      });
    } else {
      setState(() {
        _loadingPersonalTopItems = false;
        _personalTopItemsError = response.message.isNotEmpty ? response.message : '加载失败';
      });
    }
  }

  Future<void> _openPersonalTopItemEditor({TopItem? item}) async {
    final titleController = TextEditingController(text: item?.title ?? '');
    final contentController = TextEditingController(text: item?.content ?? '');
    bool saving = false;
    String? error;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              if (titleController.text.trim().isEmpty) {
                setModalState(() => error = '标题不能为空');
                return;
              }
              setModalState(() {
                saving = true;
                error = null;
              });
              ApiResponse<TopItem> resp;
              if (item == null) {
                resp = await TopItemService.createPersonalTopItem(
                  title: titleController.text.trim(),
                  content: contentController.text.trim().isEmpty ? null : contentController.text.trim(),
                );
              } else {
                resp = await TopItemService.updatePersonalTopItem(
                  item.id,
                  title: titleController.text.trim(),
                  content: contentController.text.trim(),
                );
              }

              if (!mounted) return;
              if (resp.success && resp.data != null) {
                Navigator.pop(context, true);
              } else {
                setModalState(() {
                  saving = false;
                  error = resp.message.isNotEmpty ? resp.message : '操作失败';
                });
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item == null ? '新增展示项' : '编辑展示项',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: saving ? null : submit,
                        child: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      await _loadPersonalTopItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(item == null ? '添加成功' : '更新成功')));
      }
    }
  }

  Future<void> _deletePersonalTopItem(TopItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除“${item.title}”吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirm != true) return;

    final resp = await TopItemService.deletePersonalTopItem(item.id);
    if (!mounted) return;
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除成功')));
      await _loadPersonalTopItems();
    } else {
      final msg = resp.message.isNotEmpty ? resp.message : '删除失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showTopItemDetails(TopItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        final content = (item.content ?? '').trim().isEmpty ? '暂无详细内容' : item.content!.trim();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isNotEmpty ? item.title : '未命名事项',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
                if (item.updatedAt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '更新于：${_topItemDateFormat.format(item.updatedAt!)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadCompanyTasks() async {
    setState(() {
      _loadingCompanyTasks = true;
      _companyTaskError = null;
    });

    try {
      final response = await DashboardService.getDashboardTasks();
      if (!mounted) return;
      if (response.success && response.data != null) {
        setState(() {
          _companyTasks = response.data!;
          _loadingCompanyTasks = false;
          _companyTaskError = null;
        });
      } else {
        setState(() {
          _loadingCompanyTasks = false;
          _companyTaskError = response.message.isNotEmpty ? response.message : '加载失败';
        });
      }
    } catch (e) {
      if (!mounted) return;
      print('加载任务失败: $e');
      setState(() {
        _loadingCompanyTasks = false;
        _companyTaskError = '加载失败: $e';
      });
    }
  }

  Future<void> _pinTask(String taskId) async {
    final resp = await DashboardService.pinTask(taskId);
    if (!mounted) return;
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('任务已添加')));
      await _loadCompanyTasks();
    } else {
      final msg = resp.message.isNotEmpty ? resp.message : '添加失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _unpinTask(String taskId) async {
    final resp = await DashboardService.unpinTask(taskId);
    if (!mounted) return;
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移除任务')));
      await _loadCompanyTasks();
    } else {
      final msg = resp.message.isNotEmpty ? resp.message : '移除失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _pinLog(String logId) async {
    final resp = await DashboardService.pinLog(logId);
    if (!mounted) return;
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已添加到个人日志')));
      await _loadDashboardLogs();
    } else {
      final msg = resp.message.isNotEmpty ? resp.message : '添加失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _unpinLog(String logId) async {
    final resp = await DashboardService.unpinLog(logId);
    if (!mounted) return;
    if (resp.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已移除')));
      await _loadDashboardLogs(showLoading: false);
    } else {
      final msg = resp.message.isNotEmpty ? resp.message : '移除失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openAddLogSheet() async {
    final response = await LogService.getLogs();
    if (!mounted) return;
    if (!response.success || response.data == null) {
      final msg = response.message.isNotEmpty ? response.message : '获取日志失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final pinnedIds = _dashboardLogs.map((item) => item.id).toSet();
    final List<LogEntry> logs = response.data!
        .where((log) => log.logStatus != 'completed')
        .toList()
      ..sort((a, b) {
        final aTime = a.endTime ?? DateTime.now().add(const Duration(days: 3650));
        final bTime = b.endTime ?? DateTime.now().add(const Duration(days: 3650));
        return aTime.compareTo(bTime);
      });

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '选择要展示的日志',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final isPinned = pinnedIds.contains(log.id);
                      final dueText = log.endTime != null ? _dateFormat.format(log.endTime!) : '无截止时间';
                      return ListTile(
                        enabled: !isPinned,
                        title: Text(
                          log.title.isNotEmpty ? log.title : '未命名日志',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('截止：$dueText'),
                        trailing: isPinned ? const Icon(Icons.push_pin, color: Colors.orange) : null,
                        onTap: isPinned
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _pinLog(log.id);
                              },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddTaskSheet() async {
    await _ensureCurrentUserId();
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法获取当前用户信息')));
      return;
    }

    final response = await TaskService.getTasks(limit: 100);
    if (!mounted) return;
    if (!response.success || response.data == null) {
      final msg = response.message.isNotEmpty ? response.message : '获取任务失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }

    final pinnedIds = _companyTasks.map((item) => item.id).toSet();
    final List<Task> tasks = response.data!
        .where((task) =>
            (task.assignee == currentUserId || task.creator == currentUserId) &&
            task.status != TaskStatus.completed)
        .toList()
      ..sort((a, b) => a.deadline.compareTo(b.deadline));

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '选择要展示的任务',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('暂无可添加的任务'),
                  )
                else
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final isPinned = pinnedIds.contains(task.id);
                        final dueText = _dateFormat.format(task.deadline);
                        return ListTile(
                          enabled: !isPinned,
                          title: Text(
                            task.name.isNotEmpty ? task.name : '未命名任务',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('截止：$dueText'),
                          trailing: isPinned ? const Icon(Icons.push_pin, color: Colors.orange) : null,
                          onTap: isPinned
                              ? null
                              : () async {
                                  Navigator.pop(context);
                                  await _pinTask(task.id);
                                },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openDashboardTaskDetails(String taskId) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    late ApiResponse<Task> response;
    try {
      // d:\shixun\Tujidan\lib\main.dart:662
    response = await TaskService.getTaskById(taskId);  
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) return;
    if (response.success && response.data != null) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TaskViewPage(task: response.data!)),
      );
      if (result == true) {
        await _loadCompanyTasks();
      }
    } else {
      final msg = response.message.isNotEmpty ? response.message : '加载任务详情失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _openDashboardLogDetails(String logId) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    late ApiResponse<LogEntry> response;
    try {
      // d:\shixun\Tujidan\lib\main.dart:691
    response = await LogService.getLogById(logId);
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    if (!mounted) return;
    if (response.success && response.data != null) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => LogEditPage(logEntry: response.data!)),
      );
      if (result == true) {
        await _loadDashboardLogs(showLoading: false);
      }
    } else {
      final msg = response.message.isNotEmpty ? response.message : '加载日志详情失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showNotificationsPanel() async {
    // 在显示时，获取最新的通知列表
    await _refreshNotifications();

    if (!mounted) return;

    // 标记所有为已读
    if (_hasUnread) {
      final success = await NotificationService.markAllAsRead();
      // 标记成功后，立即刷新UI，让用户看到状态变化
      if (success) {
        await _refreshNotifications();
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            Future<void> deleteNotification(NotificationItem notification) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认删除'),
                  content: const Text('确定要删除这条通知吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
                  ],
                ),
              );

              if (confirm != true) return;

              final success = await NotificationService.deleteNotification(notification.id);
              if (!mounted) return;
              if (success) {
                setModalState(() {
                  _notifications.removeWhere((n) => n.id == notification.id);
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除失败，请稍后重试')),
                );
              }
            }

            // 排序，未读的在前，已读的在后，然后按时间倒序
            _notifications.sort((a, b) {
              if (a.isRead != b.isRead) {
                return a.isRead ? 1 : -1;
              }
              return b.timestamp.compareTo(a.timestamp);
            });

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          '通知中心',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_notifications.isEmpty)
                      const Center(
                          child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text('暂无通知', style: TextStyle(color: Colors.grey)),
                      ))
                    else
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: ListView.separated(
                          itemCount: _notifications.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final notification = _notifications[index];
                            return ListTile(
                              leading: Icon(
                                notification.isRead ? Icons.notifications_none : Icons.notifications,
                                color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
                              ),
                              title: Text(
                                notification.title,
                                style: TextStyle(
                                  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                              subtitle: notification.content != null ? Text(notification.content!) : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTimestamp(notification.timestamp),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    tooltip: '删除',
                                    onPressed: () => deleteNotification(notification),
                                  ),
                                ],
                              ),
                              onTap: () {
                                // 调试信息：打印通知的完整内容
                                print('--- DEBUG NOTIFICATION ---');
                                print('Related ID: ${notification.relatedId}');
                                print('Entity Type: ${notification.entityType}');
                                print('--------------------------');

                                // 如果没有关联ID或类型，则不执行任何操作
                                if (notification.relatedId == null || notification.entityType == null) {
                                  print('Navigation skipped: relatedId or entityType is null.');
                                  return;
                                }

                                // 先关闭当前的通知面板
                                Navigator.pop(context);

                                // 根据类型决定跳转到哪里
                                if (notification.entityType == 'task') {
                                  _openDashboardTaskDetails(notification.relatedId!);
                                } else if (notification.entityType == 'log') {
                                  _openDashboardLogDetails(notification.relatedId!);
                                }
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // 关闭后再次刷新状态，确保同步
      _refreshNotifications();
    });
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return DateFormat('MM-dd').format(dt);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authService = AuthService();
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Color _statusColor(DashboardLogItem item) {
    if (item.isPinned) return Colors.orange;
    if (item.isOverdue) return Colors.redAccent;
    if (item.isDueSoon) return Colors.amber;
    return Colors.white70;
  }

  String _statusLabel(DashboardLogItem item) {
    if (item.isPinned) return '固定';
    if (item.isOverdue) return '已逾期';
    if (item.isDueSoon) return '即将到期';
    return item.logStatus == 'completed' ? '已完成' : '进行中';
  }

  Color _taskStatusColor(String status) {
    switch (status) {
      case 'in_progress':
        return Colors.green;
      case 'pending_assignment':
      case 'not_started':
        return Colors.orange;
      case 'paused':
        return Colors.blueGrey;
      case 'cancelled':
      case 'closed':
        return Colors.grey;
      case 'completed':
        return Colors.teal;
      default:
        return Colors.orange;
    }
  }

  String _taskStatusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return '进行中';
      case 'pending_assignment':
        return '待分配';
      case 'not_started':
        return '未开始';
      case 'paused':
        return '暂停';
      case 'completed':
        return '已完成';
      case 'closed':
        return '已关闭';
      case 'cancelled':
        return '已取消';
      default:
        return '待分配';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _buildTopItemsTile(),
      _buildCompanyTasksTile(),
      _buildPersonalTopItemsTile(),
      _buildPersonalLogsTile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('潘多拉', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: _showNotificationsPanel,
                tooltip: '通知',
              ),
              if (_hasUnread)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const horizontalPadding = 16.0;
            const verticalPadding = 16.0;
            const spacing = 12.0;
            final gridWidth = max(constraints.maxWidth - horizontalPadding * 2, 0.0);
            final gridHeight = max(constraints.maxHeight - verticalPadding * 2, 0.0);

            double childAspectRatio = 1.0;
            if (gridWidth > 0 && gridHeight > 0) {
              final tileWidth = (gridWidth - spacing) / 2;
              final tileHeight = (gridHeight - spacing) / 2;
              if (tileWidth > 0 && tileHeight > 0) {
                childAspectRatio = tileWidth / tileHeight;
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
              child: SizedBox.expand(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: tiles.length,
                  itemBuilder: (context, index) => tiles[index],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopItemsTile() {
    return Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Colors.pinkAccent, Colors.orangeAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.orangeAccent.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '公司十大',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                  ),
                ),
                IconButton(
                  onPressed: _loadingTopItems ? null : _loadTopItems,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '刷新',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.32),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: _loadingTopItems
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _topItemsError != null
                        ? Center(
                            child: Text(
                              _topItemsError!,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _topItems.isEmpty
                            ? const Center(
                                child: Text(
                                  '暂无展示项',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _topItems.length,
                                itemBuilder: (context, index) {
                                  final item = _topItems[index];
                                  final preview = (item.content ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
                                  return InkWell(
                                    onTap: () => _showTopItemDetails(item),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(.96),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: Colors.pinkAccent,
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title.isNotEmpty ? item.title : '未命名事项',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  preview.isNotEmpty ? preview : '暂无详细内容',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                                ),
                                                if (item.updatedAt != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _topItemDateFormat.format(item.updatedAt!),
                                                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, color: Colors.black38),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyTasksTile() {
    return Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF64B5F6), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.indigoAccent.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '十大任务',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                  ),
                ),
                IconButton(
                  onPressed: _companyTasks.length >= DashboardService.defaultLimit ? null : _openAddTaskSheet,
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  tooltip: '添加任务',
                ),
                IconButton(
                  onPressed: _loadingCompanyTasks ? null : _loadCompanyTasks,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '刷新',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.32),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: _loadingCompanyTasks
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _companyTaskError != null
                        ? Center(
                            child: Text(
                              _companyTaskError!,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _companyTasks.isEmpty
                            ? const Center(
                                child: Text(
                                  '暂无任务',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _companyTasks.length,
                                itemBuilder: (context, index) {
                                  final item = _companyTasks[index];
                                  final dueText = item.dueTime != null ? _dateFormat.format(item.dueTime!) : '无截止时间';
                                  final statusColor = _taskStatusColor(item.status);
                                  final statusLabel = _taskStatusLabel(item.status);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    // d:\shixun\Tujidan\lib\main.dart:1203
                                    onTap: () => _openDashboardTaskDetails(item.id),
                                    child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.96),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.name.isNotEmpty ? item.name : '未命名任务',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                statusLabel,
                                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '截止：$dueText',
                                          style: const TextStyle(color: Colors.black54, fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '进度：${item.progress}%',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                            TextButton(
                                              onPressed: () => _unpinTask(item.id),
                                              child: const Text('移除'),
                                            ),
                                          ],
                                        ),
                                      ],
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalTopItemsTile() {
    return Ink(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF64DFDF), Color(0xFF20BF55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.teal.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '个人十大',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (_personalTopItems.length >= 10) {
                      _showLimitDialog('个人十大展示项已满（最多10条）');
                    } else {
                      _openPersonalTopItemEditor();
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                  tooltip: '添加展示项',
                ),
                IconButton(
                  onPressed: _loadingPersonalTopItems ? null : _loadPersonalTopItems,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: '刷新',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.32),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: _loadingPersonalTopItems
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : _personalTopItemsError != null
                        ? Center(
                            child: Text(
                              _personalTopItemsError!,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _personalTopItems.isEmpty
                            ? const Center(
                                child: Text(
                                  '暂无展示项',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _personalTopItems.length,
                                itemBuilder: (context, index) {
                                  final item = _personalTopItems[index];
                                  final preview = (item.content ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.96),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: InkWell(
                                            onTap: () => _openPersonalTopItemEditor(item: item),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title.isNotEmpty ? item.title : '未命名展示项',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  preview.isNotEmpty ? preview : '暂无内容',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          tooltip: '编辑',
                                          onPressed: () => _openPersonalTopItemEditor(item: item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20),
                                          tooltip: '删除',
                                          onPressed: () => _deletePersonalTopItem(item),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalLogsTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: const [Color(0xFFFFE0B2), Color(0xFFFFB74D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.deepOrangeAccent.withOpacity(.16), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '个人日志',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (_dashboardLogs.length >= DashboardService.defaultLimit) {
                        _showLimitDialog('个人日志已满（最多${DashboardService.defaultLimit}条）');
                      } else {
                        _openAddLogSheet();
                      }
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    tooltip: '添加日志',
                  ),
                  IconButton(
                    onPressed: () => _loadDashboardLogs(showLoading: false),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    tooltip: '刷新',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.32),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _loadingLogs
                      ? const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : _logError != null
                          ? Center(
                              child: Text(
                                _logError!,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _dashboardLogs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.white70),
                                      const SizedBox(height: 8),
                                      const Text(
                                        '暂无日志',
                                        style: TextStyle(color: Colors.white70),
                                      ),
                                      const SizedBox(height: 8),
                                      TextButton(
                                        onPressed: _openAddLogSheet,
                                        child: const Text('添加日志', style: TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _dashboardLogs.length,
                                  itemBuilder: (context, index) {
                                    final item = _dashboardLogs[index];
                                    final dueText = item.endTime != null ? _dateFormat.format(item.endTime!) : '无截止时间';
                                    final statusColor = _statusColor(item);
                                    final statusLabel = _statusLabel(item);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    // d:\shixun\Tujidan\lib\main.dart:1233
                                    onTap: () => _openDashboardLogDetails(item.id),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(.96),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title.isNotEmpty ? item.title : '未命名日志',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '截止：$dueText',
                                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              TextButton(
                                                onPressed: () => _unpinLog(item.id),
                                                child: const Text('移除'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      ),
                                    );
                                  },
                                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshNotifications() async {
    if (!mounted) return;
    final notifications = await NotificationService.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _hasUnread = notifications.any((n) => !n.isRead);
    });
  }
}

class _RootDecider extends StatefulWidget {
  _RootDecider();

  @override
  State<_RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<_RootDecider> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isLoggedIn ? HomePage() : const LoginPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}