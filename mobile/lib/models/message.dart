class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['_id'] ?? json['id']).toString(),
        jobId: (json['job'] ?? '').toString(),
        senderId: (json['sender'] ?? '').toString(),
        text: json['text'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}
