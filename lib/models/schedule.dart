
class Schedule {
  final int? id;
  final int userId;
  final String title;
  final String? description;
  final String time;
  final String? iconName;
  final String? color;
  final String priority;
  final String scheduleType;
  final String status;
  final bool isRecurring;
  final DateTime? nextOccurrence;
  final int reminderMinutes;
  final bool isCompleted;
  final DateTime? createdAt;

  Schedule({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    required this.time,
    this.iconName = 'event',
    this.color = 'purple',
    this.priority = 'medium',
    this.scheduleType = 'general',
    this.status = 'Pending',
    this.isRecurring = false,
    this.nextOccurrence,
    this.reminderMinutes = 15,
    this.isCompleted = false,
    this.createdAt,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'] ?? '',
      description: json['description'],
      time: json['time'] ?? '',
      iconName: json['icon_name'] ?? 'event',
      color: json['color'] ?? 'purple',
      priority: json['priority'] ?? 'medium',
      scheduleType: json['schedule_type'] ?? 'general',
      status: json['status'] ?? 'Pending',
      isRecurring: json['is_recurring'] ?? false,
      nextOccurrence: json['next_occurrence'] != null
          ? DateTime.tryParse(json['next_occurrence'].toString())
          : null,
      reminderMinutes: json['reminder_minutes'] ?? 15,
      isCompleted: json['is_completed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'title': title,
      'description': description,
      'time': time,
      'icon_name': iconName,
      'color': color,
      'priority': priority,
      'schedule_type': scheduleType,
      'status': status,
      'is_recurring': isRecurring,
      if (nextOccurrence != null) 'next_occurrence': nextOccurrence!.toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'is_completed': isCompleted,
    };
  }

  Schedule setAllDay() {
    return Schedule(
      id: id,
      userId: userId,
      title: title,
      description: description,
      time: '00:00',
      iconName: iconName,
      color: color,
      priority: priority,
      scheduleType: 'all_day',
      status: status,
      isRecurring: isRecurring,
      nextOccurrence: nextOccurrence,
      reminderMinutes: reminderMinutes,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }
}
