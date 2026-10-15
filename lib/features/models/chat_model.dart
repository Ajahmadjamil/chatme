class ChatModel {
  final String id;
  final bool isGroup;
  final DateTime createdAt;

  // Extra fields we attach after joining with chat_members/profiles
  final String? otherUserName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? otherUsername;
  final int unreadCount; // how many unread messages in this chat
  final String? avatarUrl;  // group photo, or the other user's photo
  final String? createdBy;  // group admin's user id

  ChatModel({
    required this.id,
    required this.isGroup,
    required this.createdAt,
    this.otherUserName,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.avatarUrl,
    this.createdBy,
    this.otherUsername,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      isGroup: json['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}