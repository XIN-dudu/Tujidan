import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:test_flutter/auth_service.dart';
import 'package:test_flutter/login_page.dart';
import 'package:test_flutter/models/notification_item.dart';
import 'package:test_flutter/pages/log_list_page.dart';
import 'package:test_flutter/pages/log_view_page.dart';
import 'package:test_flutter/pages/user_profile_page.dart';
import 'package:test_flutter/pages/task_list_page.dart';
import 'package:test_flutter/services/dashboard_service.dart';
import 'package:test_flutter/models/dashboard_log_item.dart';
import 'package:test_flutter/services/log_service.dart';
import 'package:test_flutter/models/log_entry.dart';
import 'package:test_flutter/services/notification_service.dart';
import 'package:test_flutter/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('zh_CN', null);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '潘多拉',
      theme: AppTheme.getTheme(),
      home: _RootDecider(),
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
  bool _loadingLogs = false;
  String? _logError;
  List<DashboardLogItem> _dashboardLogs = [];
  bool _hasUnread = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardLogs();
    _refreshNotifications();
  }

  Future<void> _loadDashboardLogs({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loadingLogs = true;
        _logError = null;
      });
    }

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

    final pinnedIds = _dashboardLogs.where((item) => item.isPinned).map((e) => e.id).toSet();
    final List<LogEntry> logs = response.data!;

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

  void _showNotificationsPanel(BuildContext context) {
    setState(() { _hasUnread = false; });
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<List<NotificationItem>>(
          future: NotificationService.getNotifications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('加载通知失败: ${snapshot.error}'));
            }
            final notifications = List<NotificationItem>.from(snapshot.data ?? []);
            final now = DateTime.now();
            notifications.sort((a, b) {
              final at = a.timestamp.isAfter(now) ? now : a.timestamp;
              final bt = b.timestamp.isAfter(now) ? now : b.timestamp;
              final c = bt.compareTo(at);
              if (c != 0) return c;
              return a.type.index.compareTo(b.type.index);
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
                    if (notifications.isEmpty)
                      const Center(child: Text('暂无通知'))
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final notification = notifications[index];
                            return ListTile(
                              title: Text(notification.title),
                              subtitle: Text(notification.content ?? ''),
                              trailing: Text(DateFormat('MM-dd HH:mm').format(notification.timestamp)),
                            );
                          },
                          separatorBuilder: (context, index) => const Divider(height: 1),
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

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _DashboardTile(
        icon: Icons.star_rate,
        title: '公司十大重要展示项',
        start: Colors.pinkAccent,
        end: Colors.orangeAccent,
      ),
      _DashboardTile(
        icon: Icons.assignment,
        title: '公司十大派发任务',
        start: Colors.lightBlueAccent,
        end: Colors.indigoAccent,
      ),
      _DashboardTile(
        icon: Icons.insights,
        title: '个人十大重要展示项',
        start: Colors.greenAccent,
        end: Colors.teal,
      ),
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
                onPressed: () => _showNotificationsPanel(context),
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
        child: Center(
          child: ConstrainedBox(
            // 限制最大宽度和高度，保持四宫格比例
            constraints: const BoxConstraints(
              maxWidth: 600,  // 最大宽度
              maxHeight: 650, // 最大高度（稍大一点以适应间距）
            ),
            child: AspectRatio(
              // 保持接近正方形的比例
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: tiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) => tiles[index],
                ),
              ),
            ),
          ),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.book, color: Colors.deepOrange, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '个人日志',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
                    ),
                  ),
                  IconButton(
                    onPressed: _dashboardLogs.where((e) => e.isPinned).length >= DashboardService.defaultLimit
                        ? null
                        : _openAddLogSheet,
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
                                    return Container(
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
                                              if (item.isPinned)
                                                TextButton(
                                                  onPressed: () => _unpinLog(item.id),
                                                  child: const Text('取消固定'),
                                                ),
                                            ],
                                          ),
                                        ],
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
    final list = await NotificationService.getNotifications();
    if (!mounted) return;
    setState(() { _hasUnread = list.isNotEmpty; });
  }
}

class _DashboardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color start;
  final Color end;

  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {},
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [start, end],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: end.withOpacity(.2), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: start, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
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