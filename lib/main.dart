import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hitwardhini/screens/welcome_screen.dart';
import 'package:hitwardhini/screens/home_screen.dart';
import 'package:hitwardhini/screens/profile_creation_screen.dart';
import 'package:hitwardhini/screens/subscription_screen.dart';
import 'package:hitwardhini/screens/edit_profile_screen.dart';
import 'package:hitwardhini/screens/admin_screen.dart';
import 'package:hitwardhini/providers/locale_provider.dart';
import 'package:hitwardhini/l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://vqssydeyzhdoazulgzpm.supabase.co',
    anonKey: 'sb_publishable_SBglOlmrRU_jhtdtZ1yzZA_5eX61BPo',
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      title: 'Runanubandh',
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('mr'),
        Locale('en'),
      ],
      
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFDFCFB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA5C5C),
          brightness: Brightness.light,
          primary: const Color(0xFFFA5C5C), // Red-Orange
          secondary: const Color(0xFFFD8A6B), // Coral
          tertiary: const Color(0xFFFEC288), // Peach
          surface: const Color(0xFFFBEF76), // Yellow Highlight
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1B4B), // Deep Blue for contrast
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFA5C5C),
          brightness: Brightness.dark,
          primary: const Color(0xFFFA5C5C),
          secondary: const Color(0xFFFD8A6B),
          tertiary: const Color(0xFFFEC288),
          surface: const Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),

      themeMode: ThemeMode.system,
      
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/profile-creation': (context) => const ProfileCreationScreen(),
        '/dashboard': (context) => const HomeScreen(),
        '/subscription': (context) => const SubscriptionScreen(),
        '/admin': (context) => const AdminScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit-profile') {
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => EditProfileScreen(
              currentData: args ?? {},
            ),
          );
        }
        return null;
      },
    );
  }
}
