// ==================== main.dart ====================
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_strategy/url_strategy.dart';
import 'configuracoes/escolher_senha.dart';
import 'login_page.dart';
import 'home_router.dart';
import 'configuracoes/esqueci_senha.dart';
import 'configuracoes/redefinir_senha.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  setPathUrlStrategy();

  const String supabaseUrl = 'https://ikaxzlpaihdkqyjqrxyw.supabase.co';
  //const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlrYXh6bHBhaWhka3F5anFyeHl3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1MjkxNzAsImV4cCI6MjA3NzEwNTE3MH0.s9bx_3YDw3M9SozXCBRu22vZe8DJoXR9p-dyVeEH5K4';
  const String supabaseAnonKey = 'sb_publishable_5-RASBETbIIkPhsro4FIeQ_vIl1bDsu';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      autoRefreshToken: true,
      localStorage: EmptyLocalStorage(),
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted && data.event == AuthChangeEvent.passwordRecovery) {
        final currentRoute = ModalRoute.of(context)?.settings.name;
        if (currentRoute != '/redefinir-senha') {
          Navigator.pushReplacementNamed(context, '/redefinir-senha');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    
    final isRecoveryLink = uri.queryParameters.containsKey('code') || 
                           uri.toString().contains('type=recovery') ||
                           uri.toString().contains('access_token');

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Base X',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.white,
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          ),
        ),
      ),
      home: isRecoveryLink ? const RedefinirSenhaPage() : const SplashScreen(),
      routes: {
        '/home': (context) => const HomeRouter(),
        '/login': (context) => const LoginPage(),
        '/esqueci-senha': (context) => const EsqueciSenhaPage(),
        '/redefinir-senha': (context) => const RedefinirSenhaPage(),
        '/escolher-senha': (context) => const EscolherSenhaPage(),
      },
      // Adiciona fallback para rotas não encontradas
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const SplashScreen(),
        );
      },
    );
  }
}