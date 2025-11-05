import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart' show TaskPriority;
import '../services/log_service.dart';
import 'log_edit_page.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({super.key});

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedType;
  DateTime? _startTime;
  DateTime? _endTime;

  final List<String> _types = ['work', 'study', 'life', 'other'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({
    String? keyword,
    String? type,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    setState(() => _isLoading = true);
    try {
      final response = await LogService.getLogsFiltered(
        keyword: keyword ?? _searchQuery,
        type: type ?? _selectedType,
        endTime: endTime ?? _endTime,
        startTime: startTime ?? _startTime,
      );

      if (response.success && response.data != null) {
        setState(() {
          _logs = response.data!;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载日志失败: ${response.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载日志失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _navigateToEditLog(LogEntry? logEntry) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LogEditPage(logEntry: logEntry),
      ),
    );
    if (result == true) {
      _loadLogs(
        keyword: _searchQuery,
        type: _selectedType,
        startTime: _startTime,
        endTime: _endTime,
      );
    }
  }


  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'pending':
        return {
          'text': '待处理',
          'color': Colors.grey,
          'icon': Icons.pending_actions,
        };
      case 'in_progress':
      case 'inprogress':
      case 'ongoing':
      case 'active':
        return {
          'text': '进行中',
          'color': Colors.blue,
          'icon': Icons.directions_run,
        };
      case 'completed':
      case 'done':
      case 'finished':
        return {
          'text': '已完成',
          'color': Colors.green,
          'icon': Icons.check_circle,
        };
      case 'cancelled':
      case 'canceled':
        return {
          'text': '已取消',
          'color': Colors.red,
          'icon': Icons.cancel,
        };
      default:
        return {
          'text': '未知',
          'color': Colors.black,
          'icon': Icons.help_outline,
        };
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _loadLogs(
        keyword: _searchQuery,
        type: _selectedType,
        startTime: _startTime,
        endTime: _endTime,
      );
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endTime ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
      _loadLogs(
        keyword: _searchQuery,
        type: _selectedType,
        startTime: _startTime,
        endTime: _endTime,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        title: const Text('日志管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadLogs(
              keyword: _searchQuery,
              type: _selectedType,
              startTime: _startTime,
              endTime: _endTime,
            ),
            tooltip: '刷新',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索日志内容...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding:
                          const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                          _loadLogs(
                            keyword: _searchQuery,
                            type: _selectedType,
                            startTime: _startTime,
                            endTime: _endTime,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedType ?? '',
                      hint: const Text('类型'),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('全部'),
                        ),
                        ..._types.map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type),
                            )),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedType = (value == '' ? null : value));
                        _loadLogs(
                          keyword: _searchQuery,
                          type: _selectedType,
                          startTime: _startTime,
                          endTime: _endTime,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _pickStartTime,
                      icon: const Icon(Icons.date_range),
                      label: Text(_startTime == null
                          ? '开始时间'
                          : _formatDateTime(_startTime!)),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: _pickEndTime,
                      icon: const Icon(Icons.date_range),
                      label: Text(_endTime == null ? '结束时间' : _formatDateTime(_endTime!)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无日志',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('点击右下角按钮创建第一条日志',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                print('logStatus: ${log.logStatus}');
                return Dismissible(
                  key: Key(log.id),
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
                            const Text('删除日志'),
                          ],
                        ),
                        content: const Text(
                          '确定要删除这条日志吗？\n此操作无法撤销。',
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
                      final response = await LogService.deleteLog(log.id);
                      if (response.success) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  const Text('日志删除成功'),
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
                        _loadLogs(
                          keyword: _searchQuery,
                          type: _selectedType,
                          startTime: _startTime,
                          endTime: _endTime,
                        );
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
                      _loadLogs(
                        keyword: _searchQuery,
                        type: _selectedType,
                        startTime: _startTime,
                        endTime: _endTime,
                      );
                    }
                  },
                  child: Card(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.only(bottom: 12.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _navigateToEditLog(log),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _getPriorityColor(log.priority)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.article,
                                  color: _getPriorityColor(log.priority)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (log.title.isNotEmpty ? log.title : log.content),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        _getStatusInfo(log.logStatus)['icon'],
                                        size: 16,
                                        color: _getStatusInfo(log.logStatus)['color'],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _getStatusInfo(log.logStatus)['text'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getStatusInfo(log.logStatus)['color'],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      if (log.type != null) ...[
                                        Icon(Icons.label, size: 16, color: Colors.blueGrey),
                                        const SizedBox(width: 4),
                                        Text(
                                          log.type!,
                                          style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      Icon(Icons.schedule,
                                          size: 16,
                                          color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatDateTime(log.time),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(Icons.flag,
                                          size: 16,
                                          color:
                                          _getPriorityColor(log.priority)),
                                      const SizedBox(width: 4),
                                      Text(
                                        log.priority.displayName,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getPriorityColor(
                                              log.priority),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (log.taskId != null) ...[
                                        const SizedBox(width: 16),
                                        Icon(Icons.task_alt,
                                            size: 16, color: Colors.blue[600]),
                                        const SizedBox(width: 4),
                                        Text('已关联任务',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.blue[600])),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right,
                                color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToEditLog(null),
        icon: const Icon(Icons.add),
        label: const Text('写日志'),
      ),
    );
  }
}
