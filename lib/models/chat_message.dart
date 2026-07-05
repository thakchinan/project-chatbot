
/// ChatMessage เป็นโมเดลสำหรับใช้บันทึกประวัติข้อความของแชทบอท สมาร์ทเบรน AI
/// ระบุเนื้อหาผู้ส่ง บทบาท (senderRole) เวลาที่ส่ง และตัวบอกสถานะว่าเป็นข้อความจากหุ่นยนต์บอทหรือไม่
class ChatMessage {
  final int? id;
  final int userId;
  final String content;
  final String senderRole;
  final DateTime sentTimestamp;
  final DateTime? receivedAt;
  final bool isBot;

  ChatMessage({
    this.id,
    required this.userId,
    required this.content,
    this.senderRole = 'user',
    required this.sentTimestamp,
    this.receivedAt,
    this.isBot = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userId: json['user_id'],
      content: json['message'] ?? '',
      senderRole: json['sender_role'] ?? (json['is_bot'] == true ? 'bot' : 'user'),
      sentTimestamp: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'].toString())
          : DateTime.now(),
      receivedAt: json['received_at'] != null
          ? DateTime.tryParse(json['received_at'].toString())
          : null,
      isBot: json['is_bot'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'message': content,
      'sender_role': senderRole,
      'is_bot': isBot,
      if (receivedAt != null) 'received_at': receivedAt!.toIso8601String(),
    };
  }

  String exportData(int format) {
    if (format == 1) {
      return '[$senderRole] ${sentTimestamp.toString().substring(0, 16)}: $content';
    }
    return toJson().toString();
  }
}
