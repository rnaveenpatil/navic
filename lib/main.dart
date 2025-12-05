import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navic_ss/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const EnhancedNavicApp());
}

class EnhancedNavicApp extends StatelessWidget {
  const EnhancedNavicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enhanced NavIC Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        
        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        // Scaffold background
        scaffoldBackgroundColor: Colors.grey.shade50,
        
        // REMOVED CardTheme completely
        
        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        // Input decoration theme
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        
        // Floating action button theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF1B5E20),
          foregroundColor: Colors.white,
        ),
        
        // Use Material 3 design
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}