class TopItem {
  final String id;
  final String title;
  final String? content;
  final int? createdBy;
  final int orderIndex;
  final bool isVisible;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TopItem({
    required this.id,
    required this.title,
    this.content,
    this.createdBy,
    required this.orderIndex,
    required this.isVisible,
    this.createdAt,
    this.updatedAt,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) {
    return TopItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: json['content']?.toString(),
      createdBy: json['createdBy'] != null ? int.tryParse(json['createdBy'].toString()) : null,
      orderIndex: json['orderIndex'] != null ? int.tryParse(json['orderIndex'].toString()) ?? 0 : 0,
      isVisible: json['status'] == 1 || json['status']?.toString() == '1',
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
    );
  }
}








