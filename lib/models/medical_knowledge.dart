
/// MedicalKnowledge คือคลาสโมเดลสำหรับจัดเก็บข้อมูลความรู้ทางการแพทย์และสุขภาพจิต (Medical Context / RAG Database)
/// ใช้เป็นฐานข้อมูลสำหรับ RAG Service เพื่อค้นหาบริบทความรู้มาตอบคำถามและให้คำแนะนำสุขภาพจิตแก่ผู้ใช้
class MedicalKnowledge {
  final int? knowledgeId;
  final String sourceTitle;
  final String contentText;
  final DateTime? lastUpdated;
  final String category;
  final int importance;
  final bool hasSolution;
  final DateTime? addedManual;
  final List<String>? tags;

  MedicalKnowledge({
    this.knowledgeId,
    required this.sourceTitle,
    required this.contentText,
    this.lastUpdated,
    this.category = 'general',
    this.importance = 0,
    this.hasSolution = false,
    this.addedManual,
    this.tags,
  });

  factory MedicalKnowledge.fromJson(Map<String, dynamic> json) {
    return MedicalKnowledge(
      knowledgeId: json['id'],
      sourceTitle: json['title'] ?? '',
      contentText: json['content'] ?? '',
      lastUpdated: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      category: json['category'] ?? 'general',
      importance: json['importance'] ?? 0,
      hasSolution: json['has_solution'] ?? false,
      addedManual: json['added_manual'] != null
          ? DateTime.tryParse(json['added_manual'].toString())
          : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': sourceTitle,
      'content': contentText,
      'category': category,
      'importance': importance,
      'has_solution': hasSolution,
      if (addedManual != null) 'added_manual': addedManual!.toIso8601String(),
      if (tags != null) 'tags': tags,
    };
  }

  List<String> searchQuery() {
    final words = contentText.split(RegExp(r'\s+'));

    return words
        .where((w) => w.length > 2)
        .toSet()
        .toList();
  }
}
