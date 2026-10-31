import 'user.dart';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class ChatMessage {
  final String id;
  final String jobId;

  /// 'tool:<id>' for customer ↔ supplier chats, otherwise the job id.
  final String thread;
  final String senderId;
  final String recipientId;
  final String text;
  final String image;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.recipientId,
    required this.text,
    required this.createdAt,
    this.thread = '',
    this.image = '',
    this.readAt,
  });

  ChatMessage markRead() => ChatMessage(
        id: id,
        jobId: jobId,
        thread: thread,
        senderId: senderId,
        recipientId: recipientId,
        text: text,
        image: image,
        createdAt: createdAt,
        readAt: readAt ?? DateTime.now(),
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        jobId: (json['job'] ?? '').toString(),
        thread: (json['thread'] ?? json['job'] ?? '').toString(),
        senderId: (json['sender'] ?? '').toString(),
        recipientId: (json['recipient'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        image: (json['image'] ?? '').toString(),
        readAt: _date(json['readAt']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

/// One row in the inbox: a job chat (client ↔ technician) or a tool chat
/// (customer ↔ supplier).
class Conversation {
  final String kind; // job | tool
  final String toolId;
  final String toolName;
  final String toolCategory;
  final String jobId;
  final String jobTitle;
  final String jobStatus;
  final String jobCategory;
  final UserLite other;
  final ChatMessage lastMessage;
  final int unread;

  Conversation({
    this.kind = 'job',
    this.toolId = '',
    this.toolName = '',
    this.toolCategory = 'general',
    required this.jobId,
    required this.jobTitle,
    required this.jobStatus,
    required this.jobCategory,
    required this.other,
    required this.lastMessage,
    required this.unread,
  });

  bool get isTool => kind == 'tool';

  /// What the chat is about (job title or tool name).
  String get subject => isTool ? toolName : jobTitle;

  /// Same key as [ChatMessage.thread].
  String get thread => isTool ? 'tool:$toolId' : jobId;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        kind: (json['kind'] ?? 'job').toString(),
        toolId: (json['toolId'] ?? '').toString(),
        toolName: (json['toolName'] ?? '').toString(),
        toolCategory: (json['toolCategory'] ?? 'general').toString(),
        jobId: (json['jobId'] ?? '').toString(),
        jobTitle: (json['jobTitle'] ?? '').toString(),
        jobStatus: (json['jobStatus'] ?? '').toString(),
        jobCategory: (json['jobCategory'] ?? 'general').toString(),
        other: UserLite.fromAny(json['other']) ?? const UserLite(id: ''),
        lastMessage: ChatMessage.fromJson(Map<String, dynamic>.from(json['lastMessage'] ?? const {})),
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );
}
