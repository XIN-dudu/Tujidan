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
                      value: _selectedType,
                      hint: const Text('类型'),
                      items: _types.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedType = value);
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
                                  log.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
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
