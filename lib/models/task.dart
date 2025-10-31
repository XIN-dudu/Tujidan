class Task {
  final String id;
  final String name;
  final String description;
  final String assignee;
  final DateTime deadline;
  final DateTime? plannedStart; // 计划开始时间
  final TaskPriority priority;
  final TaskStatus status;
  final int progress; // 0-100
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.assignee,
    required this.deadline,
    this.plannedStart,
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    print('[Task.fromJson] Raw JSON: $json');
    return Task(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      assignee: json['assignee']?.toString() ?? json['owner_user_id']?.toString() ?? '',
      deadline: DateTime.parse((json['deadline'] ?? json['due_time'] ?? DateTime.now().toIso8601String()).toString()),
      plannedStart: json['plan_start_time'] != null ? DateTime.parse(json['plan_start_time'].toString()) : null,
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == (json['priority'] ?? 'low'),
        orElse: () => TaskPriority.low,
      ),
      status: _mapStatus(json['status']),
      progress: json['progress'] ?? 0,
      createdAt: DateTime.parse((json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()).toString()),
      updatedAt: DateTime.parse((json['updatedAt'] ?? json['updated_at'] ?? DateTime.now().toIso8601String()).toString()),
    );
  }

  static TaskStatus _mapStatus(dynamic v) {
    final s = (v ?? '').toString();
    switch (s) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'completed':
        return TaskStatus.completed;
      case 'cancelled':
        return TaskStatus.cancelled;
      case 'pending':
      case 'not_started':
      default:
        return TaskStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerUserId': assignee.isEmpty ? null : int.tryParse(assignee),
      'dueTime': deadline.toIso8601String(),
      'planStartTime': plannedStart?.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Task copyWith({
    String? id,
    String? name,
    String? description,
    String? assignee,
    DateTime? deadline,
    DateTime? plannedStart,
    TaskPriority? priority,
    TaskStatus? status,
    int? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      assignee: assignee ?? this.assignee,
      deadline: deadline ?? this.deadline,
      plannedStart: plannedStart ?? this.plannedStart,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum TaskPriority {
  high('高'),
  medium('中'),
  low('低');

  const TaskPriority(this.displayName);
  final String displayName;
}

enum TaskStatus {
  pending('待开始'),
  inProgress('进行中'),
  completed('已完成'),
  cancelled('已取消');

  const TaskStatus(this.displayName);
  final String displayName;
}
