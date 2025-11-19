import '../models/task.dart';
import '../models/api_response.dart';
import 'api_client.dart';

class TaskService {
  // 获取所有任务
  static Future<ApiResponse<List<Task>>> getTasks() async {
    return await ApiClient.get<List<Task>>(
      '/tasks',
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
  static Future<ApiResponse<Task>> createTask(Task task) async {
    return await ApiClient.post<Task>(
      '/tasks',
      body: task.toJson(),
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
    // 创建成功后立即分配
    return await publishTask(response.data!.id, ownerUserId: assigneeId);
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

  // 分配任务（指定负责人并置为未开始）
  static Future<ApiResponse<Task>> publishTask(
    String taskId, {
    String? ownerUserId,
  }) async {
    return await ApiClient.post<Task>(
      '/tasks/$taskId/publish',
      body: {if (ownerUserId != null) 'ownerUserId': int.tryParse(ownerUserId)},
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 接收任务（自己接单并置为进行中）
  static Future<ApiResponse<Task>> acceptTask(String taskId) async {
    return await ApiClient.post<Task>(
      '/tasks/$taskId/accept',
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 取消接收任务（将状态改回待开始）
  static Future<ApiResponse<Task>> cancelAcceptTask(String taskId) async {
    return await ApiClient.post<Task>(
      '/tasks/$taskId/cancel-accept',
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
