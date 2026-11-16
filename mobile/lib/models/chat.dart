import 'json.dart';
import 'user.dart';

/// Identifies a chat thread: a job (client ↔ technician), a tool
/// (customer ↔ supplier) or a support conversation (a user ↔ the SureFix
/// team), plus the other side.
class ChatTarget {
  final String jobId;
  final String toolId;
  final String otherId;
  final String otherName;
  final String otherAvatar;
  final String subject; // job title or tool name

  /// Support conversations: whose conversation it is.
  final String supportUser;

  /// Support conversations: the viewer is on the SureFix team (an admin).
  final bool asTeam;

  /// Support conversations: what the team is writing about ("Job: …").
  final String about;

  const ChatTarget({
    this.jobId = '',
    this.toolId = '',
    required this.otherId,
    this.otherName = '',
    this.otherAvatar = '',
    this.subject = '',
    this.supportUser = '',
    this.asTeam = false,
    this.about = '',
  });

  /// A user's conversation with SureFix Support. [asTeam]: opened by an
  /// admin, who sees the user; otherwise the user sees "SureFix Support".
  factory ChatTarget.support({required String userId, String name = '', String avatar = '', bool asTeam = false, String about = ''}) => ChatTarget(
        supportUser: userId,
        asTeam: asTeam,
        about: about,
        otherId: asTeam ? userId : supportId,
        otherName: asTeam ? name : supportName,
        otherAvatar: asTeam ? avatar : '',
      );

  static const supportId = 'support';
  static const supportName = 'SureFix Support';

  bool get isSupport => supportUser.isNotEmpty;
  bool get isTool => toolId.isNotEmpty;

  /// Key used by realtime events (`thread`) to address this conversation.
  String get thread => isSupport ? 'support:$supportUser' : (isTool ? 'tool:$toolId' : jobId);

  String get path {
    if (isSupport) return asTeam ? '/api/messages/support/$supportUser' : '/api/messages/support';
    return isTool ? '/api/messages/tool/$toolId' : '/api/messages/$jobId';
  }
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

  /// Support conversations: written by the SureFix team.
  final bool fromSupport;

  /// Support conversations: what the team's message is about.
  final String about;

  /// Who wrote it (admins see their teammates' names in support chats).
  final String senderName;

  const Message({
    required this.id,
    this.thread = '',
    this.senderId = '',
    this.recipientId = '',
    this.text = '',
    this.image = '',
    this.read = false,
    this.createdAt,
    this.fromSupport = false,
    this.about = '',
    this.senderName = '',
  });

  Message markedRead() => Message(
        id: id,
        thread: thread,
        senderId: senderId,
        recipientId: recipientId,
        text: text,
        image: image,
        read: true,
        createdAt: createdAt,
        fromSupport: fromSupport,
        about: about,
        senderName: senderName,
      );

  factory Message.fromJson(Json j) => Message(
        id: idOf(j),
        thread: str(j['thread'], j['support'] != null ? 'support:${idOf(j['support'])}' : (j['tool'] != null ? 'tool:${idOf(j['tool'])}' : idOf(j['job']))),
        senderId: idOf(j['sender']),
        recipientId: idOf(j['recipient']),
        text: str(j['text']),
        image: str(j['image']),
        read: j['readAt'] != null,
        createdAt: date(j['createdAt']),
        fromSupport: j['fromSupport'] == true,
        about: str(j['about']),
        senderName: str(j['senderName']),
      );
}

/// One row of the inbox.
class Conversation {
  final bool isSupport;
  final String supportUser;
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
    this.isSupport = false,
    this.supportUser = '',
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

  ChatTarget get target => isSupport
      ? ChatTarget.support(userId: supportUser, name: other.name, avatar: other.avatar, asTeam: other.id != ChatTarget.supportId)
      : ChatTarget(jobId: jobId, toolId: toolId, otherId: other.id, otherName: other.name, otherAvatar: other.avatar, subject: title);

  /// Identifies the row (one per thread and person).
  String get key => isSupport ? 'support:$supportUser' : '${isTool ? 'tool:$toolId' : jobId}|${other.id}';

  factory Conversation.fromJson(Json j) {
    final tool = j['kind'] == 'tool';
    final last = asJson(j['lastMessage']);
    if (j['kind'] == 'support') {
      return Conversation(
        isSupport: true,
        supportUser: idOf(j['supportUser'] ?? last['support']),
        isTool: false,
        title: 'SureFix Support',
        other: User.fromJson(asJson(j['other'])),
        last: Message.fromJson(last),
        unread: integer(j['unread']),
      );
    }
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
