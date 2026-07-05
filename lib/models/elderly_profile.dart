
/// ElderlyProfile คือโมเดลสำหรับจัดเก็บข้อมูลประวัติผู้สูงอายุ/ผู้รับการดูแลเฉพาะบุคคล
/// มีการจัดเก็บประวัติทางการแพทย์ โรคประจำตัว ยาที่ใช้เป็นประจำ ข้อมูลการเคลื่อนไหว และผู้ติดต่อกรณีฉุกเฉิน
class ElderlyProfile {
  final int? profileId;
  final int userId;
  final String? firstName;
  final String? lastName;
  final String? nickName;
  final int? age;
  final String? relationship;
  final String? emergencyContact;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final List<String>? medicalConditions;
  final List<String>? allergies;
  final List<String>? currentMedications;
  final String? mobilityStatus;
  final String? cognitiveStatus;
  final String? doctorName;
  final String? doctorPhone;
  final String? hospitalName;
  final String? insuranceInfo;
  final String? specialNeeds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ElderlyProfile({
    this.profileId,
    required this.userId,
    this.firstName,
    this.lastName,
    this.nickName,
    this.age,
    this.relationship,
    this.emergencyContact,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.medicalConditions,
    this.allergies,
    this.currentMedications,
    this.mobilityStatus,
    this.cognitiveStatus,
    this.doctorName,
    this.doctorPhone,
    this.hospitalName,
    this.insuranceInfo,
    this.specialNeeds,
    this.createdAt,
    this.updatedAt,
  });

  factory ElderlyProfile.fromJson(Map<String, dynamic> json) {
    return ElderlyProfile(
      profileId: json['profile_id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      nickName: json['nick_name'],
      age: json['age'],
      relationship: json['relationship'],
      emergencyContact: json['emergency_contact'],
      dateOfBirth: json['date_of_birth'],
      gender: json['gender'],
      bloodType: json['blood_type'],
      heightCm: json['height_cm']?.toDouble(),
      weightKg: json['weight_kg']?.toDouble(),
      medicalConditions: json['medical_conditions'] != null
          ? List<String>.from(json['medical_conditions'])
          : null,
      allergies: json['allergies'] != null
          ? List<String>.from(json['allergies'])
          : null,
      currentMedications: json['current_medications'] != null
          ? List<String>.from(json['current_medications'])
          : null,
      mobilityStatus: json['mobility_status'],
      cognitiveStatus: json['cognitive_status'],
      doctorName: json['doctor_name'],
      doctorPhone: json['doctor_phone'],
      hospitalName: json['hospital_name'],
      insuranceInfo: json['insurance_info'],
      specialNeeds: json['special_needs'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (nickName != null) 'nick_name': nickName,
      if (age != null) 'age': age,
      if (relationship != null) 'relationship': relationship,
      if (emergencyContact != null) 'emergency_contact': emergencyContact,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'blood_type': bloodType,
      if (heightCm != null) 'height_cm': heightCm,
      if (weightKg != null) 'weight_kg': weightKg,
      if (medicalConditions != null) 'medical_conditions': medicalConditions,
      if (allergies != null) 'allergies': allergies,
      if (currentMedications != null) 'current_medications': currentMedications,
      if (mobilityStatus != null) 'mobility_status': mobilityStatus,
      if (cognitiveStatus != null) 'cognitive_status': cognitiveStatus,
      if (doctorName != null) 'doctor_name': doctorName,
      if (doctorPhone != null) 'doctor_phone': doctorPhone,
      if (hospitalName != null) 'hospital_name': hospitalName,
      if (insuranceInfo != null) 'insurance_info': insuranceInfo,
      if (specialNeeds != null) 'special_needs': specialNeeds,
    };
  }

  int setAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int calculatedAge = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      calculatedAge--;
    }
    return calculatedAge;
  }

  String getFullName() {
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }
}
