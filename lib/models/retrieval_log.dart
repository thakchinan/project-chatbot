
/// RetrievalLog คือคลาสโมเดลสำหรับจัดเก็บบันทึกประวัติการเรียกค้นหาข้อมูลความรู้ทางการแพทย์และ RAG Context
/// บันทึกข้อความการสืบค้น (queryText) คะแนนความคล้ายคลึง (similarityScore) วิธีการค้นหา และความสำเร็จของการจับคู่
class RetrievalLog {
  final int? logId;
  final int? messageId;
  final int? knowledgeId;
  final String? queryText;
  final double? similarityScore;
  final int? rankOrder;
  final bool wasUsed;
  final String searchMethod;
  final DateTime? createdAt;

  RetrievalLog({
    this.logId,
    this.messageId,
    this.knowledgeId,
    this.queryText,
    this.similarityScore,
    this.rankOrder,
    this.wasUsed = false,
    this.searchMethod = 'vector',
    this.createdAt,
  });

  factory RetrievalLog.fromJson(Map<String, dynamic> json) {
    return RetrievalLog(
      logId: json['log_id'],
      messageId: json['message_id'],
      knowledgeId: json['knowledge_id'],
      queryText: json['query_text'],
      similarityScore: json['similarity_score']?.toDouble(),
      rankOrder: json['rank_order'],
      wasUsed: json['was_used'] ?? false,
      searchMethod: json['search_method'] ?? 'vector',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (messageId != null) 'message_id': messageId,
      if (knowledgeId != null) 'knowledge_id': knowledgeId,
      if (queryText != null) 'query_text': queryText,
      if (similarityScore != null) 'similarity_score': similarityScore,
      if (rankOrder != null) 'rank_order': rankOrder,
      'was_used': wasUsed,
      'search_method': searchMethod,
    };
  }

  String logDetailed() {
    return 'RetrievalLog[query=$queryText, score=$similarityScore, method=$searchMethod, used=$wasUsed]';
  }
}
