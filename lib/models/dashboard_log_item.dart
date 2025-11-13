class DashboardLogItem {
  final String id;
  final String title;
  final String content;
  final String logStatus;
  final String? priority;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final DateTime? pinnedAt;

  DashboardLogItem({
    required this.id,
    required this.title,
    required this.content,
    required this.logStatus,
    this.priority,
    this.startTime,
    this.endTime,
    this.createdAt,
    this.updatedAt,
    this.isPinned = false,
    this.pinnedAt,
  });

  factory DashboardLogItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return DashboardLogItem(
      id: json['id'].toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      logStatus: (json['logStatus'] ?? 'pending').toString(),
      priority: json['priority']?.toString(),
      startTime: _parseDate(json['startTime']),
      endTime: _parseDate(json['endTime']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      isPinned: json['isPinned'] == true || json['isPinned'] == 1,
      pinnedAt: _parseDate(json['pinnedAt']),
    );
  }

  bool get isOverdue => endTime != null && endTime!.isBefore(DateTime.now());
  bool get isDueSoon {
    if (endTime == null) return false;
    final now = DateTime.now();
    return !isOverdue && endTime!.difference(now).inHours <= 24;
  }
}

