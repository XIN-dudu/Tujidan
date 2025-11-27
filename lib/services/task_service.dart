import '../models/task.dart';
import '../models/api_response.dart';
import 'api_client.dart';

class TaskService {
  // 获取所有任务
  static Future<ApiResponse<List<Task>>> getTasks({int limit = 50}) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<Task>>(
      '/tasks$query',
      fromJson: (data) => (data as List)
          .map((item) => Task.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // 根据ID获取任务
  static Future<ApiResponse<Task>> getTaskById(String id) async {
    return await ApiClient.get<Task>(
      '/tasks/$id',
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 根据负责人获取任务
  static Future<ApiResponse<List<Task>>> getTasksByAssignee(
    String assignee,
  ) async {
    return await ApiClient.get<List<Task>>(
      '/tasks?assignee=$assignee',
      fromJson: (data) => (data as List)
          .map((item) => Task.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  // 创建任务
  static Future<ApiResponse<Task>> createTask(
    Task task, {
    String? ownerUserId,
  }) async {
    final body = Map<String, dynamic>.from(task.toJson());
    final override = ownerUserId?.trim();
    if (override != null && override.isNotEmpty) {
      body['ownerUserId'] = int.tryParse(override) ?? override;
    }
    return await ApiClient.post<Task>(
      '/tasks',
      body: body,
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 创建并分配任务
  static Future<ApiResponse<Task>> createAndPublishTask(
    Task task, {
    String? assigneeId,
  }) async {
    final response = await createTask(task);
    if (!response.success || response.data == null) {
      return response;
    }
    final targetId = assigneeId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return response;
    }
    final createdTask = response.data!;
    if (createdTask.assigneeId.isNotEmpty && createdTask.assigneeId == targetId) {
      // 已分配到目标负责人，无需再调用 publish（避免被当作撤回）。
      return response;
    }
    final publishResponse = await publishTask(createdTask.id, ownerUserId: targetId);
    return publishResponse;
  }

  // 更新任务
  static Future<ApiResponse<Task>> updateTask(Task task) async {
    return await ApiClient.patch<Task>(
      '/tasks/${task.id}',
      body: task.toJson(),
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 更新任务进度
  static Future<ApiResponse<Task>> updateTaskProgress(
    String taskId,
    int progress,
  ) async {
    return await ApiClient.patch<Task>(
      '/tasks/$taskId/progress',
      body: {'progress': progress},
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 分配任务（指定负责人后直接进入进行中）
  static Future<ApiResponse<Task>> publishTask(
    String taskId, {
    String? ownerUserId,
  }) async {
    final parsedOwner =
        ownerUserId != null && ownerUserId.trim().isNotEmpty ? int.tryParse(ownerUserId) : null;
    return await ApiClient.post<Task>(
      '/tasks/$taskId/publish',
      body: {if (parsedOwner != null) 'ownerUserId': parsedOwner},
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 删除任务
  static Future<ApiResponse<void>> deleteTask(String id) async {
    return await ApiClient.delete<void>('/tasks/$id');
  }

  // 搜索任务
  static Future<ApiResponse<List<Task>>> searchTasks(String query) async {
    return await ApiClient.get<List<Task>>(
      '/tasks?keyword=$query',
      fromJson: (data) => (data as List)
          .map((item) => Task.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
