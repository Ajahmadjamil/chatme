class ChatModel {
  final String id;
  final bool isGroup;
  final DateTime createdAt;

  /// Display title: other person's name (DM) or group name.
  final String? otherUserName;
  final String? otherUserId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageType;
  final String? lastMessageSenderId;
  final int unreadCount;
  final String? myRole;
  final String? avatarUrl;

  ChatModel({
    required this.id,
    required this.isGroup,
    required this.createdAt,
    this.otherUserName,
    this.otherUserId,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageType,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.myRole,
    this.avatarUrl,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      isGroup: json['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUserName: json['display_name'] as String? ?? json['name'] as String?,
      otherUserId: json['other_user_id'] as String?,
      lastMessage: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      lastMessageType: json['last_message_type'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      myRole: json['my_role'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
