class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String status;
  final DateTime createdAt;
  final String messageType;
  final String? mediaUrl;
  final int? durationSeconds;
  final DateTime? expiresAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? replyToId;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.status,
    required this.createdAt,
    this.messageType = 'text',
    this.mediaUrl,
    this.durationSeconds,
    this.expiresAt,
    this.editedAt,
    this.deletedAt,
    this.replyToId,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.parse(json['created_at'] as String),
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'] as String)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      replyToId: json['reply_to_id'] as String?,
    );
  }
}
