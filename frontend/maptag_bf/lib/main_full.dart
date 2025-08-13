import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // Initialize local database
  try {
    await DatabaseService.instance.database;
    print('Database initialized successfully');
  } catch (e) {
    print('Database initialization error: $e');
  }
  
  runApp(const MapTagApp());
}

class MapTagApp extends StatelessWidget {
  const MapTagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapTag BF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class AppColors {
  static const Color primary = Colors.green;
  static const Color secondary = Colors.blue;
  static const Color accent = Colors.orange;
  static const Color error = Colors.red;
  static const Color warning = Colors.amber;
  static const Color success = Colors.green;
  static const Color info = Colors.blue;
  
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF212121);
  static const Color onSurfaceVariant = Color(0xFF757575);
  
  static const Color cardBorder = Color(0xFFE0E0E0);
  static const Color divider = Color(0xFFE0E0E0);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.onSurface,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.onSurface,
  );
  
  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    color: AppColors.onSurface,
  );
  
  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    color: AppColors.onSurface,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.onSurfaceVariant,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}