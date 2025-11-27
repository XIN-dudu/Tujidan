class Task {
  final String id;
  final String name;
  final String description;
  final String assignee; // 展示名称
  final String assigneeId; // 负责人ID
  final String creator; // 创建者ID
  final DateTime deadline;
  final DateTime? plannedStart; // 计划开始时间
  final TaskPriority priority;
  final TaskStatus status;
  final int progress; // 0-100
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> images;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.assignee,
    this.assigneeId = '',
    required this.creator,
    required this.deadline,
    this.plannedStart,
    required this.priority,
    required this.status,
    required this.progress,
    required this.createdAt,
    required this.updatedAt,
    List<String>? images,
  }) : images = images ?? const [];

  factory Task.fromJson(Map<String, dynamic> json) {
    final rawName = (json['assignee'] ?? json['owner_user_name'] ?? '').toString();
    final rawId = (json['owner_user_id'] ?? json['assignee_id'])?.toString() ?? '';
    final normalizedName = rawName.trim().isNotEmpty ? rawName.toString() : '';
    final normalizedId = rawId.trim();

    return Task(
      id: (json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      assignee: normalizedName.isNotEmpty ? normalizedName : normalizedId,
      assigneeId: normalizedId,
      creator:
          json['creator']?.toString() ??
          json['creator_user_id']?.toString() ??
          '',
      deadline: DateTime.parse(
        (json['deadline'] ??
                json['due_time'] ??
                DateTime.now().toIso8601String())
            .toString(),
      ),
      plannedStart: json['plan_start_time'] != null
          ? DateTime.parse(json['plan_start_time'].toString())
          : null,
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == (json['priority'] ?? 'low'),
        orElse: () => TaskPriority.low,
      ),
      status: _mapStatus(json['status']),
      progress: json['progress'] ?? 0,
      createdAt: DateTime.parse(
        (json['createdAt'] ??
                json['created_at'] ??
                DateTime.now().toIso8601String())
            .toString(),
      ),
      updatedAt: DateTime.parse(
        (json['updatedAt'] ??
                json['updated_at'] ??
                DateTime.now().toIso8601String())
            .toString(),
      ),
      images: _parseImages(json['images']),
    );
  }

  static List<String> _parseImages(dynamic source) {
    if (source is List) {
      return source
          .map((item) {
            if (item is String) return item;
            if (item is Map<String, dynamic>) {
              return item['dataUri']?.toString() ??
                  item['image_data']?.toString();
            }
            return null;
          })
          .whereType<String>()
          .toList();
    }
    return const [];
  }

  static TaskStatus _mapStatus(dynamic v) {
    final s = (v ?? '').toString().toLowerCase().replaceAll('_', '');
    switch (s) {
      case 'pendingassignment':
      case 'tobeassigned':
        return TaskStatus.pending_assignment;
      case 'notstarted':
        return TaskStatus.not_started;
      case 'inprogress':
        return TaskStatus.in_progress;
      case 'paused':
        return TaskStatus.paused;
      case 'completed':
        return TaskStatus.completed;
      case 'closed':
        return TaskStatus.closed;
      case 'cancelled':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending_assignment;
    }
  }

  Map<String, dynamic> toJson() {
    final ownerSource =
        assigneeId.isNotEmpty ? assigneeId : assignee;
    final ownerUserId = int.tryParse(ownerSource);

    return {
      'id': id,
      'name': name,
      'description': description,
      'ownerUserId': ownerUserId,
      'dueTime': deadline.toIso8601String(),
      'planStartTime': plannedStart?.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'progress': progress,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'creator': creator,
      'images': images,
    };
  }

  Task copyWith({
    String? id,
    String? name,
    String? description,
    String? assignee,
    String? assigneeId,
    String? creator,
    DateTime? deadline,
    DateTime? plannedStart,
    TaskPriority? priority,
    TaskStatus? status,
    int? progress,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? images,
  }) {
    return Task(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      assignee: assignee ?? this.assignee,
      assigneeId: assigneeId ?? this.assigneeId,
      creator: creator ?? this.creator,
      deadline: deadline ?? this.deadline,
      plannedStart: plannedStart ?? this.plannedStart,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      images: images ?? this.images,
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
  pending_assignment('待分配'),
  not_started('未开始'),
  in_progress('进行中'),
  paused('已暂停'),
  completed('已完成'),
  closed('已关闭'),
  cancelled('已取消');

  const TaskStatus(this.displayName);
  final String displayName;
}
