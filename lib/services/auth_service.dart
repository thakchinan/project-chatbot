import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart' as app_models;
import 'supabase_service.dart';

/// AuthService จัดการระบบยืนยันตัวตน (Authentication) ทั้งหมดของแอปพลิเคชัน
/// รองรับ 2 ช่องทางการเข้าสู่ระบบ:
///   1. Email + Password (ผ่าน Supabase Auth พร้อม bcrypt hash อัตโนมัติ)
///   2. Google Sign-In (ผ่าน OAuth 2.0 + Supabase Auth)
///
/// หลังล็อกอินสำเร็จจะซิงค์ข้อมูลกับตาราง users ในฐานข้อมูล
/// เพื่อให้ userId ใช้งานได้ทั่วทั้งแอป
class AuthService {
  // ═══════════════════════════════════════════
  //  การลงทะเบียนด้วย Email + Password
  // ═══════════════════════════════════════════

  /// สมัครสมาชิกใหม่ด้วย email และ password
  /// Supabase Auth จะ:
  ///   - Hash password ด้วย bcrypt อัตโนมัติ
  ///   - ส่ง email ยืนยันตัวตนไปยังอีเมลที่ระบุ
  ///   - สร้างบัญชีใน auth.users
  ///
  /// หลังจากนั้นจะสร้าง row ในตาราง users เพื่อเชื่อมกับระบบ
  static Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? birthDate,
  }) async {
    try {
      final client = SupabaseService.client;

      // ขั้นตอนที่ 1: สร้างบัญชีผ่าน Supabase Auth
      final authResponse = await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (authResponse.user == null) {
        return {'success': false, 'message': 'ไม่สามารถสร้างบัญชีได้ กรุณาลองใหม่'};
      }

      // ขั้นตอนที่ 2: สร้าง row ในตาราง users เพื่อเชื่อมกับระบบแอป
      final syncResult = await _syncUserToDatabase(
        authUserId: authResponse.user!.id,
        email: email,
        fullName: fullName,
        phone: phone,
        birthDate: birthDate,
        authProvider: 'email',
      );

      if (syncResult['success'] != true) {
        return syncResult;
      }

      return {
        'success': true,
        'message': 'สมัครสมาชิกสำเร็จ กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชี',
        'user': syncResult['user'],
        'needs_verification': true,
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _translateAuthError(e.message)};
    } catch (e) {
      debugPrint('❌ SignUp Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการสมัครสมาชิก: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  การเข้าสู่ระบบด้วย Email + Password
  // ═══════════════════════════════════════════

  /// เข้าสู่ระบบด้วย email และ password
  /// Supabase Auth จะตรวจสอบ email/password กับ bcrypt hash ที่เก็บไว้
  static Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final client = SupabaseService.client;

      // เข้าสู่ระบบผ่าน Supabase Auth
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {'success': false, 'message': 'ไม่สามารถเข้าสู่ระบบได้'};
      }

      // ดึงข้อมูลจากตาราง users โดยใช้ auth_user_id
      final syncResult = await _getOrCreateUserProfile(authResponse.user!);

      if (syncResult['success'] != true) {
        return syncResult;
      }

      return {
        'success': true,
        'message': 'เข้าสู่ระบบสำเร็จ',
        'user': syncResult['user'],
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _translateAuthError(e.message)};
    } catch (e) {
      debugPrint('❌ SignIn Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  การเข้าสู่ระบบด้วย Google
  // ═══════════════════════════════════════════

  /// เข้าสู่ระบบด้วยบัญชี Google ผ่าน OAuth 2.0
  /// ขั้นตอน:
  ///   1. เปิดหน้าล็อกอิน Google ให้ผู้ใช้เลือกบัญชี
  ///   2. รับ idToken จาก Google
  ///   3. ส่ง idToken ให้ Supabase Auth ตรวจสอบ
  ///   4. ซิงค์ข้อมูลกับตาราง users
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // ขั้นตอนที่ 1: เปิดหน้า Google Sign-In
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // ผู้ใช้กดยกเลิกการเข้าสู่ระบบ
        return {'success': false, 'message': 'ยกเลิกการเข้าสู่ระบบด้วย Google'};
      }

      // ขั้นตอนที่ 2: ดึง Authentication Token
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return {'success': false, 'message': 'ไม่สามารถรับ Token จาก Google ได้'};
      }

      // ขั้นตอนที่ 3: ส่ง Token ให้ Supabase Auth
      final client = SupabaseService.client;
      final authResponse = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (authResponse.user == null) {
        return {'success': false, 'message': 'ไม่สามารถยืนยันตัวตนกับ Supabase ได้'};
      }

      // ขั้นตอนที่ 4: ซิงค์ข้อมูลกับตาราง users
      final syncResult = await _getOrCreateUserProfile(
        authResponse.user!,
        displayName: googleUser.displayName,
        photoUrl: googleUser.photoUrl,
        authProvider: 'google',
      );

      if (syncResult['success'] != true) {
        return syncResult;
      }

      return {
        'success': true,
        'message': 'เข้าสู่ระบบด้วย Google สำเร็จ',
        'user': syncResult['user'],
      };
    } catch (e) {
      debugPrint('❌ Google SignIn Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการเข้าสู่ระบบด้วย Google: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  การรีเซ็ตรหัสผ่าน (Forgot Password)
  // ═══════════════════════════════════════════

  /// ส่งอีเมลลิงก์สำหรับรีเซ็ตรหัสผ่าน
  /// ผู้ใช้จะได้รับอีเมลพร้อมลิงก์สำหรับตั้งรหัสผ่านใหม่
  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      final client = SupabaseService.client;
      await client.auth.resetPasswordForEmail(email);

      return {
        'success': true,
        'message': 'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมล $email แล้ว กรุณาตรวจสอบกล่องจดหมาย',
      };
    } on AuthException catch (e) {
      return {'success': false, 'message': _translateAuthError(e.message)};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถส่งอีเมลรีเซ็ตรหัสผ่านได้: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  การส่งอีเมลยืนยันซ้ำ
  // ═══════════════════════════════════════════

  /// ส่งอีเมลยืนยันตัวตนซ้ำ (กรณีผู้ใช้ยังไม่ได้กดยืนยัน)
  static Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    try {
      final client = SupabaseService.client;
      await client.auth.resend(
        type: OtpType.signup,
        email: email,
      );

      return {
        'success': true,
        'message': 'ส่งอีเมลยืนยันตัวตนซ้ำไปที่ $email แล้ว',
      };
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถส่งอีเมลยืนยันซ้ำได้: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  ยืนยัน OTP สำหรับสมัครสมาชิก
  // ═══════════════════════════════════════════

  /// ยืนยัน OTP 6 หลักจากอีเมลสำหรับการสมัครสมาชิก
  /// Supabase จะส่งรหัสยืนยัน (Token) ไปพร้อมกับอีเมลยืนยันตัวตน
  static Future<Map<String, dynamic>> verifySignUpOTP({
    required String email,
    required String token,
  }) async {
    try {
      final client = SupabaseService.client;
      final response = await client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );

      if (response.user != null) {
        // ออกจากระบบหลังยืนยันสำเร็จ เพื่อให้ผู้ใช้ล็อกอินด้วย email/password อย่างเป็นทางการ
        await client.auth.signOut();
        return {
          'success': true,
          'message': 'ยืนยันอีเมลสำเร็จ',
        };
      }
      return {'success': false, 'message': 'รหัสยืนยันไม่ถูกต้อง กรุณาลองใหม่'};
    } on AuthException catch (e) {
      return {'success': false, 'message': _translateAuthError(e.message)};
    } catch (e) {
      debugPrint('❌ Verify OTP Error: $e');
      return {'success': false, 'message': 'เกิดข้อผิดพลาดในการยืนยัน: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  การออกจากระบบ
  // ═══════════════════════════════════════════

  /// ออกจากระบบทั้ง Supabase Auth และ Google Sign-In
  static Future<void> signOut() async {
    try {
      final client = SupabaseService.client;
      await client.auth.signOut();

      // ออกจาก Google Sign-In ด้วย (ถ้าเคยล็อกอินด้วย Google)
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (_) {
        // ไม่เป็นไรถ้า Google Sign-In ไม่ได้เริ่มต้น
      }
    } catch (e) {
      debugPrint('❌ SignOut Error: $e');
    }
  }

  // ═══════════════════════════════════════════
  //  ตรวจสอบสถานะ Session
  // ═══════════════════════════════════════════

  /// ตรวจสอบว่าผู้ใช้ล็อกอินอยู่หรือไม่ (มี session ที่ยังใช้ได้)
  static bool get isLoggedIn {
    try {
      final client = SupabaseService.client;
      return client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  /// ดึงข้อมูล Auth User ปัจจุบัน (จาก Supabase Auth)
  static User? get currentAuthUser {
    try {
      final client = SupabaseService.client;
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// ดึงข้อมูลผู้ใช้จากตาราง users โดยใช้ session ที่มีอยู่
  /// ใช้สำหรับ auto-login เมื่อเปิดแอปซ้ำ
  static Future<Map<String, dynamic>> restoreSession() async {
    try {
      final authUser = currentAuthUser;
      if (authUser == null) {
        return {'success': false, 'message': 'ไม่มี session ที่ใช้ได้'};
      }

      final syncResult = await _getOrCreateUserProfile(authUser);
      return syncResult;
    } catch (e) {
      debugPrint('❌ Restore Session Error: $e');
      return {'success': false, 'message': 'ไม่สามารถกู้คืน session ได้'};
    }
  }

  // ═══════════════════════════════════════════
  //  ฟังก์ชันภายใน — ซิงค์ข้อมูลกับตาราง users
  // ═══════════════════════════════════════════

  /// สร้าง row ใหม่ในตาราง users สำหรับผู้ใช้ที่เพิ่งสมัครสมาชิก
  static Future<Map<String, dynamic>> _syncUserToDatabase({
    required String authUserId,
    required String email,
    String? fullName,
    String? phone,
    String? birthDate,
    String authProvider = 'email',
  }) async {
    try {
      final client = SupabaseService.client;

      // ตรวจสอบว่ามี row ในตาราง users ที่ผูกกับ auth_user_id นี้แล้วหรือไม่
      final existing = await client
          .from('users')
          .select()
          .eq('auth_user_id', authUserId)
          .maybeSingle();

      if (existing != null) {
        // มี row อยู่แล้ว — ดึงข้อมูลมาใช้เลย
        return {
          'success': true,
          'user': existing,
        };
      }

      // ตรวจซ้ำด้วย email (กรณีผู้ใช้เก่าที่ยังไม่มี auth_user_id)
      final existingByEmail = await client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingByEmail != null) {
        // พบผู้ใช้เดิมด้วย email — อัปเดต auth_user_id
        await client
            .from('users')
            .update({
              'auth_user_id': authUserId,
              'auth_provider': authProvider,
              'email_verified': authProvider == 'google', // Google = verified อัตโนมัติ
            })
            .eq('id', existingByEmail['id']);

        final updated = await client
            .from('users')
            .select()
            .eq('id', existingByEmail['id'])
            .single();

        return {
          'success': true,
          'user': updated,
        };
      }

      // สร้าง row ใหม่ในตาราง users
      // ใช้ email เป็น username (ตัดส่วน @domain ออก)
      final username = email.split('@').first;

      final response = await client
          .from('users')
          .insert({
            'username': username,
            'email': email,
            'full_name': fullName,
            'phone': phone,
            'birth_date': birthDate,
            'auth_user_id': authUserId,
            'auth_provider': authProvider,
            'email_verified': authProvider == 'google',
          })
          .select()
          .single();

      // สร้าง user_settings สำหรับผู้ใช้ใหม่
      await client.from('user_settings').insert({
        'user_id': response['id'],
      });

      return {
        'success': true,
        'user': response,
      };
    } catch (e) {
      debugPrint('❌ Sync User Error: $e');
      return {'success': false, 'message': 'ไม่สามารถบันทึกข้อมูลผู้ใช้ได้: $e'};
    }
  }

  /// ดึงหรือสร้าง profile ในตาราง users สำหรับ Auth User ที่ล็อกอินแล้ว
  static Future<Map<String, dynamic>> _getOrCreateUserProfile(
    User authUser, {
    String? displayName,
    String? photoUrl,
    String authProvider = 'email',
  }) async {
    try {
      final client = SupabaseService.client;

      // ค้นหา user จาก auth_user_id
      var userRow = await client
          .from('users')
          .select()
          .eq('auth_user_id', authUser.id)
          .maybeSingle();

      // ถ้าไม่พบ ลองค้นจาก email
      if (userRow == null && authUser.email != null) {
        userRow = await client
            .from('users')
            .select()
            .eq('email', authUser.email!)
            .maybeSingle();

        if (userRow != null) {
          // พบผู้ใช้เดิม — อัปเดต auth_user_id
          await client
              .from('users')
              .update({
                'auth_user_id': authUser.id,
                'auth_provider': authProvider,
                'email_verified': true,
              })
              .eq('id', userRow['id']);

          userRow = await client
              .from('users')
              .select()
              .eq('id', userRow['id'])
              .single();
        }
      }

      // ถ้ายังไม่พบ สร้างใหม่ (กรณี Google Sign-In ครั้งแรก)
      if (userRow == null) {
        final result = await _syncUserToDatabase(
          authUserId: authUser.id,
          email: authUser.email ?? '',
          fullName: displayName ?? authUser.userMetadata?['full_name'],
          authProvider: authProvider,
        );

        if (result['success'] != true) return result;
        userRow = result['user'];

        // อัปเดต avatar ถ้ามี (จาก Google)
        if (photoUrl != null && userRow != null) {
          await client
              .from('users')
              .update({'avatar_url': photoUrl})
              .eq('id', userRow['id']);
          userRow['avatar_url'] = photoUrl;
        }
      }

      // แปลงเป็น app_models.User
      final appUser = app_models.User.fromJson(userRow!);

      return {
        'success': true,
        'user': userRow,
        'app_user': appUser,
      };
    } catch (e) {
      debugPrint('❌ Get/Create User Profile Error: $e');
      return {'success': false, 'message': 'ไม่สามารถดึงข้อมูลผู้ใช้ได้: $e'};
    }
  }

  // ═══════════════════════════════════════════
  //  แปลข้อผิดพลาด Supabase Auth เป็นภาษาไทย
  // ═══════════════════════════════════════════

  /// แปลข้อความ error จาก Supabase Auth ให้เป็นภาษาไทยที่เข้าใจง่าย
  static String _translateAuthError(String errorMessage) {
    final msg = errorMessage.toLowerCase();

    if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
      return 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
    }
    if (msg.contains('email not confirmed')) {
      return 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
    }
    if (msg.contains('user already registered') || msg.contains('already been registered')) {
      return 'อีเมลนี้ถูกใช้สมัครสมาชิกแล้ว';
    }
    if (msg.contains('password')) {
      return 'รหัสผ่านไม่ถูกต้องตามเกณฑ์ กรุณาตั้งรหัสผ่านใหม่';
    }
    if (msg.contains('rate limit') || 
        msg.contains('too many requests') || 
        msg.contains('security purposes') || 
        msg.contains('after 30 seconds') || 
        msg.contains('seconds')) {
      return 'เพื่อความปลอดภัยในการส่งคำขอ กรุณารอสักครู่ (ประมาณ 30 วินาที) แล้วลองใหม่อีกครั้ง';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'ไม่สามารถเชื่อมต่อเครือข่ายได้ กรุณาตรวจสอบอินเทอร์เน็ต';
    }

    return 'เกิดข้อผิดพลาด: $errorMessage';
  }
}
