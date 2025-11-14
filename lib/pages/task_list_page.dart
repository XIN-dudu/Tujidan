import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/api_response.dart';
import '../services/task_service.dart';
import '../services/user_service.dart';
import 'task_edit_page.dart';
import 'task_view_page.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/page_transitions.dart';
import '../widgets/animated_list_item.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  bool _loading = false;
  bool _canCreate = false;
  List<Task> _tasks = [];
  List<Task> _allTasks = []; // 存储所有任务，用于本地筛选
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _deadlineFilter; // 结束时间筛选
  DateTime? _startTimeFilter; // 开始时间筛选
  final ScrollController _scrollController = ScrollController();
  bool _showSearchBar = true;
  double _lastScrollOffset = 0;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _load();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentOffset = _scrollController.offset;
    if (currentOffset > _lastScrollOffset && currentOffset > 50) {
      // 向下滚动且超过50px，隐藏搜索栏
      if (_showSearchBar) {
        setState(() => _showSearchBar = false);
      }
    } else if (currentOffset < _lastScrollOffset || currentOffset <= 50) {
      // 向上滚动或回到顶部，显示搜索栏
      if (!_showSearchBar) {
        setState(() => _showSearchBar = true);
      }
    }
    _lastScrollOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterTasks() {
    final keyword = _searchController.text.trim().toLowerCase();
    setState(() {
      _tasks = _allTasks.where((task) {
        // 关键词筛选
        final matchesKeyword = keyword.isEmpty ||
            task.name.toLowerCase().contains(keyword) ||
            task.description.toLowerCase().contains(keyword);
        
        // 结束时间筛选
        final matchesDeadline = _deadlineFilter == null ||
            task.deadline.isBefore(_deadlineFilter!);

        // 开始时间筛选
        final matchesStartTime = _startTimeFilter == null ||
            (task.plannedStart?.isAfter(_startTimeFilter!) ?? false);

        return matchesKeyword && matchesDeadline && matchesStartTime;
      }).toList();
    });
  }

  Future<void> _pickStartTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startTimeFilter ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startTimeFilter = DateTime(
          picked.year,
          picked.month,
          picked.day,
          0,
          0,
          0,
        );
      });
      _filterTasks();
    }
  }

  Future<void> _pickEndTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _deadlineFilter ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _deadlineFilter = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
      _filterTasks();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }
  

  Future<void> _checkPermissions() async {
    final roles = await _userService.getUserRoles();
    // founder/admin和dept_head可以创建任务，staff不能创建
    final isFounderOrAdmin = roles.contains('admin') || roles.contains('founder');
    final isDeptHead = roles.contains('dept_head');
    final isStaff = roles.contains('staff');
    
    setState(() => _canCreate = isFounderOrAdmin || isDeptHead);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ApiResponse<List<Task>> res = await TaskService.getTasks();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _allTasks = res.data ?? [];
    });
    _filterTasks();
  }

  void _onSearch(String value) {
    _filterTasks();
  }

  Future<void> _create() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      SlidePageRoute(page: const TaskEditPage()),
    );
    if (changed == true) _load();
  }

  Future<void> _open(Task task) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      SlidePageRoute(page: TaskViewPage(task: task)),
    );
    if (changed == true) _load();
  }

  Color _priorityColor(TaskPriority p) {
    switch (p) {
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
        title: const Text('任务列表', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: _showSearchBar ? 1.0 : 0.0,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: _showSearchBar ? 1.0 : 0.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, -20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: '搜索任务...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _filterTasks();
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() {});
                                _onSearch(value);
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                TextButton.icon(
                                  onPressed: _pickStartTime,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(_startTimeFilter == null
                                      ? '开始时间'
                                      : _formatDateTime(_startTimeFilter!)),
                                ),
                                if (_startTimeFilter != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _startTimeFilter = null;
                                      });
                                      _filterTasks();
                                    },
                                    tooltip: '清除开始时间',
                                  ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: _pickEndTime,
                                  icon: const Icon(Icons.date_range),
                                  label: Text(_deadlineFilter == null
                                      ? '结束时间'
                                      : _formatDateTime(_deadlineFilter!)),
                                ),
                                if (_deadlineFilter != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _deadlineFilter = null;
                                      });
                                      _filterTasks();
                                    },
                                    tooltip: '清除结束时间',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          Expanded(
            child: _loading
                    ? ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                        itemCount: 5,
                        itemBuilder: (context, index) => const ListItemSkeleton(),
                      )
                    : _tasks.isEmpty
                        ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无任务',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _canCreate
                                  ? '点击右下角按钮创建第一个任务'
                                  : '暂无符合条件的任务',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final t = _tasks[index];
                    return AnimatedListItem(
                      index: index,
                      child: Dismissible(
                        key: Key(t.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        margin: const EdgeInsets.only(bottom: 12.0),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[400]!, Colors.red[600]!],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_forever,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(height: 6),
                            Text(
                              '删除',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        // 显示确认对话框
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, 
                                     color: Colors.orange[600], size: 24),
                                const SizedBox(width: 8),
                                const Text('删除任务'),
                              ],
                            ),
                            content: const Text(
                              '确定要删除这个任务吗？\n此操作无法撤销。',
                              style: TextStyle(fontSize: 16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[600],
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                ),
                                child: const Text('取消'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('删除'),
                              ),
                            ],
                          ),
                        );
                        return confirmed ?? false;
                      },
                      onDismissed: (direction) async {
                        // 执行删除操作
                        try {
                          final response = await TaskService.deleteTask(t.id);
                          if (response.success) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      const SizedBox(width: 8),
                                      const Text('任务删除成功'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                            // 重新加载列表
                            _load();
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.error, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('删除失败: ${response.message}')),
                                    ],
                                  ),
                                  backgroundColor: Colors.red[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                            // 如果删除失败，重新加载列表
                            _load();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('删除失败: $e')),
                                  ],
                                ),
                                backgroundColor: Colors.red[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                          // 如果删除失败，重新加载列表
                          _load();
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _priorityColor(t.priority),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.task,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            t.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    t.status.displayName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '进度: ${t.progress}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                          ),
                          onTap: () => _open(t),
                        ),
                      ),
                      ),
                    );
                  },
                ),
            ),
          ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('新建任务'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
            )
          : null,
    );
  }
}


