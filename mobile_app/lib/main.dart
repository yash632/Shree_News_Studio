import 'package:flutter/material.dart';
import 'screens/studio_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShreeNewsApp());
}

class ShreeNewsApp extends StatelessWidget {
  const ShreeNewsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shree News Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFDC2626),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
          ),
        ),
      ),
      home: const StudioScreen(),
    );
  }
}

