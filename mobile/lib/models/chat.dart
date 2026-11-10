import 'json.dart';
import 'user.dart';

/// Identifies a chat thread: a job (client ↔ technician) or a tool
/// (customer ↔ supplier), plus the other person.
class ChatTarget {
  final String jobId;
  final String toolId;
  final String otherId;
  final String otherName;
  final String otherAvatar;
  final String subject; // job title or tool name
  const ChatTarget({this.jobId = '', this.toolId = '', required this.otherId, this.otherName = '', this.otherAvatar = '', this.subject = ''});

  bool get isTool => toolId.isNotEmpty;

  /// Key used by realtime events (`thread`) to address this conversation.
  String get thread => isTool ? 'tool:$toolId' : jobId;

  String get path => isTool ? '/api/messages/tool/$toolId' : '/api/messages/$jobId';
}

class Message {
  final String id;
  final String thread;
  final String senderId;
  final String recipientId;
  final String text;
  final String image;
  final bool read;
  final DateTime? createdAt;
  const Message({required this.id, this.thread = '', this.senderId = '', this.recipientId = '', this.text = '', this.image = '', this.read = false, this.createdAt});

  factory Message.fromJson(Json j) => Message(
        id: idOf(j),
        thread: str(j['thread'], j['tool'] != null ? 'tool:${idOf(j['tool'])}' : idOf(j['job'])),
        senderId: idOf(j['sender']),
        recipientId: idOf(j['recipient']),
        text: str(j['text']),
        image: str(j['image']),
        read: j['readAt'] != null,
        createdAt: date(j['createdAt']),
      );
}

/// One row of the inbox.
class Conversation {
  final bool isTool;
  final String jobId;
  final String toolId;
  final String title; // job title or tool name
  final String category;
  final String toolImage;
  final String jobStatus;
  final User other;
  final Message last;
  final int unread;
  const Conversation({
    required this.isTool,
    this.jobId = '',
    this.toolId = '',
    this.title = '',
    this.category = '',
    this.toolImage = '',
    this.jobStatus = '',
    required this.other,
    required this.last,
    this.unread = 0,
  });

  ChatTarget get target =>
      ChatTarget(jobId: jobId, toolId: toolId, otherId: other.id, otherName: other.name, otherAvatar: other.avatar, subject: title);

  factory Conversation.fromJson(Json j) {
    final tool = j['kind'] == 'tool';
    return Conversation(
      isTool: tool,
      jobId: idOf(j['jobId']),
      toolId: idOf(j['toolId']),
      title: str(tool ? j['toolName'] : j['jobTitle']),
      category: str(tool ? j['toolCategory'] : j['jobCategory']),
      toolImage: str(j['toolImage']),
      jobStatus: str(j['jobStatus']),
      other: User.fromJson(asJson(j['other'])),
      last: Message.fromJson(asJson(j['lastMessage'])),
      unread: integer(j['unread']),
    );
  }
}
