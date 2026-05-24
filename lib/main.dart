import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/brain_provider.dart';
import 'screens/auth/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'services/rag_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env early but don't block the UI startup on other platform plugins.
  await dotenv.load(fileName: ".env");

  // Start the app first to make the UI available while we initialize
  // heavyweight or platform-specific services asynchronously. This helps
  // isolate platform-specific initialization errors (like macOS plugin
  // implementations) from preventing the app from launching.
  runApp(const MyApp());

  // Initialize Supabase and RAG embeddings after the app is up. Wrap with
  // error handling so failures on unsupported platforms don't crash the app.
  Future.microtask(() async {
    try {
      await SupabaseService.initialize();
    } catch (e, st) {
      debugPrint('⚠️ Supabase init failed: $e');
      debugPrint('$st');
    }

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
