import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../models/task.dart';
import '../services/log_service.dart';
import 'log_edit_page.dart';
import 'log_view_page.dart';

class LogListPage extends StatefulWidget {
  const LogListPage({super.key});

  @override
  State<LogListPage> createState() => _LogListPageState();
}

class _LogListPageState extends State<LogListPage> {
  List<LogEntry> _logs = [];
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final response = await LogService.getLogs();
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

  List<LogEntry> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((log) =>
        log.content.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _navigateToEditLog(LogEntry? logEntry) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => LogEditPage(logEntry: logEntry),
      ),
    );
    
    if (result == true) {
      // 如果保存成功，重新加载日志列表
      _loadLogs();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
        title: const Text('日志管理'),
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
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索日志内容...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.2),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // 日志列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredLogs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              '暂无日志',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '点击右下角按钮创建第一条日志',
                              style: TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = _filteredLogs[index];
                          return Card(
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(log.priority).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(Icons.article, color: _getPriorityColor(log.priority)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            log.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                _formatDateTime(log.time),
                                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                              ),
                                              const SizedBox(width: 16),
                                              Icon(Icons.flag, size: 16, color: _getPriorityColor(log.priority)),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.priority.displayName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: _getPriorityColor(log.priority),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if (log.taskId != null) ...[
                                                const SizedBox(width: 16),
                                                Icon(Icons.task_alt, size: 16, color: Colors.blue[600]),
                                                const SizedBox(width: 4),
                                                Text('已关联任务', style: TextStyle(fontSize: 12, color: Colors.blue[600])),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                                  ],
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
