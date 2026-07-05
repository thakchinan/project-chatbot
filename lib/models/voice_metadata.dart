
/// VoiceMetadata คือคลาสโมเดลจัดเก็บเมทาดาต้าของไฟล์เสียงพูดในการทำแชท
/// บันทึกตำแหน่งที่อยู่ไฟล์เสียงภาษาไทย อารมณ์ที่ตรวจจับได้จากเสียง ดัชนีความเครียดในเสียง (stressIndex) และระดับความดัง
class VoiceMetadata {
  final int? voiceId;
  final int? messageId;
  final String audioFilePath;
  final String? emotionDetected;
  final String? contentText;
  final String? detectedLanguage;
  final double? durationSeconds;
  final String senderType;
  final double? sentimentScore;
  final double? stressIndex;
  final double? pitchAvg;
  final double? volumeAvg;
  final double? speechRate;
  final DateTime? createdAt;

  VoiceMetadata({
    this.voiceId,
    this.messageId,
    this.audioFilePath = '',
    this.emotionDetected,
    this.contentText,
    this.detectedLanguage = 'th',
    this.durationSeconds,
    this.senderType = 'user',
    this.sentimentScore,
    this.stressIndex,
    this.pitchAvg,
    this.volumeAvg,
    this.speechRate,
    this.createdAt,
  });

  factory VoiceMetadata.fromJson(Map<String, dynamic> json) {
    return VoiceMetadata(
      voiceId: json['voice_id'],
      messageId: json['message_id'],
      audioFilePath: json['audio_file_url'] ?? '',
      emotionDetected: json['emotion_detected'],
      contentText: json['content_text'],
      detectedLanguage: json['detected_language'] ?? 'th',
      durationSeconds: json['duration_seconds']?.toDouble(),
      senderType: json['sender_type'] ?? 'user',
      sentimentScore: json['sentiment_score']?.toDouble(),
      stressIndex: json['stress_index']?.toDouble(),
      pitchAvg: json['pitch_avg']?.toDouble(),
      volumeAvg: json['volume_avg']?.toDouble(),
      speechRate: json['speech_rate']?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (messageId != null) 'message_id': messageId,
      'audio_file_url': audioFilePath,
      if (emotionDetected != null) 'emotion_detected': emotionDetected,
      if (contentText != null) 'content_text': contentText,
      'detected_language': detectedLanguage,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'sender_type': senderType,
      if (sentimentScore != null) 'sentiment_score': sentimentScore,
      if (stressIndex != null) 'stress_index': stressIndex,
      if (pitchAvg != null) 'pitch_avg': pitchAvg,
      if (volumeAvg != null) 'volume_avg': volumeAvg,
      if (speechRate != null) 'speech_rate': speechRate,
    };
  }

  Map<String, dynamic> analyzeAudioProficiency() {
    return {
      'emotion': emotionDetected ?? 'unknown',
      'stress_level': (stressIndex ?? 0) > 50 ? 'high' : 'normal',
      'sentiment': (sentimentScore ?? 0) > 0 ? 'positive' : 'negative',
      'speech_rate_status': (speechRate ?? 0) > 150 ? 'fast' : 'normal',
    };
  }
}
