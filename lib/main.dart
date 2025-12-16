import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase here
  await Supabase.initialize(
    url: 'https://mjiwtzxowailozpcufwm.supabase.co',
    anonKey: 'sb_publishable_6ibNBuObInyb9wfzAJGjxA_xmkRAs1O', // Replace with actual key from dashboard
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Educate Me',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color.fromARGB(255, 11, 11, 11),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color.fromARGB(255, 0, 0, 0),
              foregroundColor: Colors.white,
            ),
          ),
          themeMode: mode,
          home: const LoginPage(),
        );
      },
    );
  }
}
