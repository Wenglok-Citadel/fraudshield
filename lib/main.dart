import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'app_router.dart';
import 'screens/root_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const FraudShieldApp());
  MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
  ],
  
  child: Consumer<ThemeProvider>(
    builder: (_, theme, __) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: theme.mode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: const RootScreen(),
      );
    },
  ),
);

}

class FraudShieldApp extends StatelessWidget {
  const FraudShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'FraudShield',
        onGenerateRoute: AppRouter.generate,
        home: const RootScreen(),
      ),
    );
  }
}


