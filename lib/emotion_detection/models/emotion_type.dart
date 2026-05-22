enum EmotionType {
  happy,
  sad,
  angry,
  fearful,
  surprised,
  disgusted,
  neutral,
  calm,
  stressed,
  anxious,
  focused;

  String get label {
    switch (this) {
      case EmotionType.happy:
        return 'มีความสุข';
      case EmotionType.sad:
        return 'เศร้า';
      case EmotionType.angry:
        return 'โกรธ';
      case EmotionType.fearful:
        return 'กลัว';
      case EmotionType.surprised:
        return 'ประหลาดใจ';
      case EmotionType.disgusted:
        return 'รังเกียจ';
      case EmotionType.neutral:
        return 'ปกติ';
      case EmotionType.calm:
        return 'สงบ';
      case EmotionType.stressed:
        return 'เครียด';
      case EmotionType.anxious:
        return 'วิตกกังวล';
      case EmotionType.focused:
        return 'มีสมาธิ';
    }
  }

  String get emoji {
    switch (this) {
      case EmotionType.happy:
        return '😊';
      case EmotionType.sad:
        return '😢';
      case EmotionType.angry:
        return '😠';
      case EmotionType.fearful:
        return '😨';
      case EmotionType.surprised:
        return '😲';
      case EmotionType.disgusted:
        return '🤢';
      case EmotionType.neutral:
        return '😐';
      case EmotionType.calm:
        return '😌';
      case EmotionType.stressed:
        return '😰';
      case EmotionType.anxious:
        return '😟';
      case EmotionType.focused:
        return '🧠';
    }
  }

  static EmotionType fromString(String value) {
    return EmotionType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => EmotionType.neutral,
    );
  }
}
