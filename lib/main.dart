import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/brain_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/rag_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env early but don't block the UI startup on other platform plugins.
  await dotenv.load(fileName: ".env");

  // Initialize Firebase and Supabase BEFORE the app starts so they are ready
  // when WelcomeScreen checks for a saved user (auto-login).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseMessaging.instance.requestPermission();
    debugPrint('🔥 Firebase Initialized');
  } catch (e) {
    debugPrint('⚠️ Firebase init failed (needs google-services.json): $e');
  }

  try {
    await SupabaseService.initialize();
  } catch (e, st) {
    debugPrint('⚠️ Supabase init failed: $e');
    debugPrint('$st');
  }

  runApp(const MyApp());

  // Initialize RAG embeddings after the app is up (non-critical).
  Future.microtask(() async {
    try {
      final result = await RAGService.updateEmbeddings();
      if (result is Map && result['success'] == true && (result['updated_count'] ?? 0) > 0) {
        debugPrint('🧠 RAG: Updated ${result['updated_count']} embeddings');
      }
    } catch (e, st) {
      debugPrint('⚠️ RAG: Could not update embeddings - $e');
      debugPrint('$st');
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BrainProvider(),
      child: MaterialApp(
        title: 'Smart Brain',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryBlue),
          useMaterial3: true,
          textTheme: GoogleFonts.promptTextTheme(),
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}
