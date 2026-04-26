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

  await dotenv.load(fileName: ".env");

  await SupabaseService.initialize();

  RAGService.updateEmbeddings().then((result) {
    if (result['success'] == true && (result['updated_count'] ?? 0) > 0) {
      debugPrint('🧠 RAG: Updated ${result['updated_count']} embeddings');
    }
  }).catchError((e) {
    debugPrint('⚠️ RAG: Could not update embeddings - $e');
  });

  runApp(const MyApp());
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
