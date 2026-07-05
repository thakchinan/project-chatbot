import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/brain_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/rag_service.dart';

/// จุดเริ่มต้นการทำทำงานหลักของแอปพลิเคชัน (Main Entry Point)
void main() async {
  // บังคับให้เตรียมตัวแปรสำหรับการทำงานของเฟรมเวิร์กก่อนเริ่มวาด UI
  WidgetsFlutterBinding.ensureInitialized();

  // โหลดตัวแปรสภาพแวดล้อมที่สำคัญ (เช่น API Keys) จากไฟล์ .env
  await dotenv.load(fileName: ".env");

  // เริ่มทำการรันแอปพลิเคชันหลักทันที เพื่อแสดงหน้าตาแอปให้ผู้ใช้เห็นก่อนโดยไม่ต้องรอ
  runApp(const MyApp());

  // เริ่มทำการดึงบริการหลังบ้านที่มีขนาดใหญ่ เช่น Supabase และการเชื่อมโยงระบบเวกเตอร์ค้นหา (RAG) 
  // แบบอะซิงโครนัส (Asynchronous background) เพื่อไม่ให้ขัดจังหวะความลื่นไหลในหน้าจอแรก
  Future.microtask(() async {
    try {
      await SupabaseService.initialize();
    } catch (e, st) {
      debugPrint('⚠️ Supabase init failed: $e');
      debugPrint('$st');
    }

    try {
      final result = await RAGService.updateEmbeddings();
      if (result['success'] == true && (result['updated_count'] ?? 0) > 0) {
        debugPrint('🧠 RAG: Updated ${result['updated_count']} embeddings');
      }
    } catch (e, st) {
      debugPrint('⚠️ RAG: Could not update embeddings - $e');
      debugPrint('$st');
    }
  });
}

/// คลาสสแตรตเจียหลักของแอปพลิเคชัน (MyApp)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ลงทะเบียนการจัดการระดับรัฐหลัก (State Management) ของคลื่นสมอง (BrainProvider) ให้ใช้งานได้ทั่วทั้งแอป
    return ChangeNotifierProvider(
      create: (_) => BrainProvider(),
      child: MaterialApp(
        title: 'Smart Brain',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme, // ใช้ชุดรูปแบบธีมสะอาดทางการแพทย์ CGH Hospital
        home: const WelcomeScreen(), // เปิดแอปที่หน้าจอเข้ายินดีต้อนรับ (WelcomeScreen)
      ),
    );
  }
}
