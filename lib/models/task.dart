class Task {
  final String id;
  final String name;
  final String description;
  final String assignee;
  final DateTime deadline;
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
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      assignee: json['assignee'] ?? '',
      deadline: DateTime.parse(json['deadline'] ?? DateTime.now().toIso8601String()),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => TaskPriority.low,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TaskStatus.pending,
      ),
      progress: json['progress'] ?? 0,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'assignee': assignee,
      'deadline': deadline.toIso8601String(),
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
