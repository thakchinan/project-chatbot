import 'package:flutter/material.dart';
import '../../models/user.dart';

/// Class UserProvider สำหรับเก็บข้อมูลผู้ใช้งานปัจจุบัน (User Session)
/// ใช้ในการจัดการสถานะการล็อกอินและซิงค์ข้อมูลผู้ใช้ระหว่างหน้าจอต่างๆ
class UserProvider extends ChangeNotifier {
  // ข้อมูลผู้ใช้งานที่เข้าสู่ระบบอยู่ในปัจจุบัน (เป็น null หากยังไม่ได้ล็อกอิน)
  User? _user;

  // ดึงข้อมูลผู้ใช้ปัจจุบัน
  User? get user => _user;

  // ตรวจสอบว่าผู้ใช้เข้าสู่ระบบอยู่หรือไม่
  bool get isLoggedIn => _user != null;

  /// ตั้งค่าผู้ใช้งานปัจจุบันเมื่อล็อกอินสำเร็จ และแจ้งเตือนหน้าจอต่าง ๆ ให้รีเฟรชสถิติผู้ใช้
  void setUser(User user) {
    _user = user;
    notifyListeners();
  }

  /// ล้างข้อมูลผู้ใช้ปัจจุบันเมื่อทำการออกจากระบบ (Logout) และสั่งรีเซ็ตหน้าจอต่างๆ กลับไปหน้าต้อนรับ
  void clearUser() {
    _user = null;
    notifyListeners();
  }
}
