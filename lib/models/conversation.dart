
class Conversation {
  final int? conversationId;
  final int userId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? summary;
  final bool isActive;
  final bool enableAI;
  final int messageCount;
  final double? sentimentAvg;
  final String? endConversationText;
  final DateTime? createdAt;

  Conversation({
    this.conversationId,
    required this.userId,
    this.startDate,
    this.endDate,
    this.summary,
    this.isActive = true,
    this.enableAI = true,
    this.messageCount = 0,
    this.sentimentAvg,
    this.endConversationText,
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      conversationId: json['conversation_id'],
      userId: json['user_id'],
      startDate: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      endDate: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      summary: json['topic_summary'],
      isActive: json['is_active'] ?? true,
      enableAI: json['enable_ai'] ?? true,
      messageCount: json['message_count'] ?? 0,
      sentimentAvg: json['sentiment_avg']?.toDouble(),
      endConversationText: json['end_conversation_text'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_active': isActive,
      'enable_ai': enableAI,
      if (summary != null) 'topic_summary': summary,
      if (sentimentAvg != null) 'sentiment_avg': sentimentAvg,
      if (endConversationText != null) 'end_conversation_text': endConversationText,
    };
  }

  Conversation toggleAI() {
    return Conversation(
      conversationId: conversationId,
      userId: userId,
      startDate: startDate,
      endDate: endDate,
      summary: summary,
      isActive: isActive,
      enableAI: !enableAI,
      messageCount: messageCount,
      sentimentAvg: sentimentAvg,
      endConversationText: endConversationText,
      createdAt: createdAt,
    );
  }

  String endConversation() {
    return summary ?? 'การสนทนาจบลงเรียบร้อย';
  }
}
