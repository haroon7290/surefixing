DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  bool get unread => readAt == null;
  String? get jobId => data['jobId']?.toString();
  String? get toolId => data['toolId']?.toString();
  String? get rentalId => data['rentalId']?.toString();

  AppNotification asRead() => AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        data: data,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : <String, dynamic>{},
        readAt: _date(json['readAt']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}
