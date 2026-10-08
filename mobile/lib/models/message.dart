import 'user.dart';

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

class ChatMessage {
  final String id;
  final String jobId;
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
    this.image = '',
    this.readAt,
  });

  ChatMessage markRead() => ChatMessage(
        id: id,
        jobId: jobId,
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
        senderId: (json['sender'] ?? '').toString(),
        recipientId: (json['recipient'] ?? '').toString(),
        text: (json['text'] ?? '').toString(),
        image: (json['image'] ?? '').toString(),
        readAt: _date(json['readAt']),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

/// One row in the inbox.
class Conversation {
  final String jobId;
  final String jobTitle;
  final String jobStatus;
  final String jobCategory;
  final UserLite other;
  final ChatMessage lastMessage;
  final int unread;

  Conversation({
    required this.jobId,
    required this.jobTitle,
    required this.jobStatus,
    required this.jobCategory,
    required this.other,
    required this.lastMessage,
    required this.unread,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        jobId: (json['jobId'] ?? '').toString(),
        jobTitle: (json['jobTitle'] ?? '').toString(),
        jobStatus: (json['jobStatus'] ?? '').toString(),
        jobCategory: (json['jobCategory'] ?? 'general').toString(),
        other: UserLite.fromAny(json['other']) ?? const UserLite(id: ''),
        lastMessage: ChatMessage.fromJson(Map<String, dynamic>.from(json['lastMessage'] ?? const {})),
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );
}
