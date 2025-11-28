class DashboardTaskItem {
  final String id;
  final String name;
  final String description;
  final String status;
  final String priority;
  final int progress;
  final DateTime? planStartTime;
  final DateTime? dueTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isPinned;
  final DateTime? pinnedAt;

  DashboardTaskItem({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.priority,
    required this.progress,
    this.planStartTime,
    this.dueTime,
    this.createdAt,
    this.updatedAt,
    this.isPinned = true,
    this.pinnedAt,
  });

  factory DashboardTaskItem.fromJson(Map<String, dynamic> json) {
    DateTime? _parseDate(dynamic value) {
      if (value == null) return null;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    return DashboardTaskItem(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending_assignment').toString(),
      priority: (json['priority'] ?? 'low').toString(),
      progress: int.tryParse(json['progress']?.toString() ?? '') ?? 0,
      planStartTime: _parseDate(json['planStartTime']),
      dueTime: _parseDate(json['dueTime']),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      isPinned: json['isPinned'] == true || json['isPinned'] == 1,
      pinnedAt: _parseDate(json['pinnedAt']),
    );
  }

  bool get isOverdue => dueTime != null && dueTime!.isBefore(DateTime.now());

  bool get isDueSoon {
    if (dueTime == null) return false;
    final now = DateTime.now();
    return !isOverdue && dueTime!.difference(now).inHours <= 24;
  }
}













