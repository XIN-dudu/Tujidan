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
  static Future<ApiResponse<List<Task>>> getTasksByAssignee(String assignee) async {
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

  // 更新任务
  static Future<ApiResponse<Task>> updateTask(Task task) async {
    return await ApiClient.put<Task>(
      '/tasks/${task.id}',
      body: task.toJson(),
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 更新任务进度
  static Future<ApiResponse<Task>> updateTaskProgress(String taskId, int progress) async {
    return await ApiClient.put<Task>(
      '/tasks/$taskId/progress',
      body: {'progress': progress},
      fromJson: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }

  // 删除任务
  static Future<ApiResponse<void>> deleteTask(String id) async {
    return await ApiClient.delete<void>('/tasks/$id');
  }

  // 搜索任务
  static Future<ApiResponse<List<Task>>> searchTasks(String query) async {
    return await ApiClient.get<List<Task>>('/tasks?keyword=$query',
        fromJson: (data) => (data as List)
            .map((item) => Task.fromJson(item as Map<String, dynamic>))
            .toList());
  }
}
