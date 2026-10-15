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
  final String? replyToId; // NEW
  final List<String> deletedFor;

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
    this.replyToId,
    this.deletedFor = const [],
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String,
      status: json['status'] as String? ?? 'sent',
      createdAt: DateTime.parse(json['created_at'] as String),
      messageType: json['message_type'] as String? ?? 'text',
      mediaUrl: json['media_url'] as String?,
      durationSeconds: json['duration_seconds'] as int?,
      replyToId: json['reply_to_id'] as String?,
      deletedFor: (json['deleted_for'] as List?)
          ?.map((e) => e as String)
          .toList() ??
          [],
    );
  }
}