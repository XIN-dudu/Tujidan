import '../models/api_response.dart';
import '../models/top_item.dart';
import 'api_client.dart';

class TopItemService {
  static Future<ApiResponse<List<TopItem>>> getTopItems({int limit = 10}) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<TopItem>>(
      '/top-items$query',
      fromJson: (data) => (data as List)
          .map((item) => TopItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<ApiResponse<List<TopItem>>> getPersonalTopItems({int limit = 10}) async {
    final query = limit > 0 ? '?limit=$limit' : '';
    return await ApiClient.get<List<TopItem>>(
      '/personal/top-items$query',
      fromJson: (data) => (data as List)
          .map((item) => TopItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<ApiResponse<TopItem>> createPersonalTopItem({
    required String title,
    String? content,
  }) async {
    return await ApiClient.post<TopItem>(
      '/personal/top-items',
      body: {
        'title': title,
        if (content != null) 'content': content,
      },
      fromJson: (data) => TopItem.fromJson(data as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<TopItem>> updatePersonalTopItem(
    String id, {
    String? title,
    String? content,
    int? orderIndex,
    int? status,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (content != null) body['content'] = content;
    if (orderIndex != null) body['orderIndex'] = orderIndex;
    if (status != null) body['status'] = status;

    return await ApiClient.patch<TopItem>(
      '/personal/top-items/$id',
      body: body.isEmpty ? null : body,
      fromJson: (data) => TopItem.fromJson(data as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<void>> deletePersonalTopItem(String id) async {
    return await ApiClient.delete<void>('/personal/top-items/$id');
  }
}


