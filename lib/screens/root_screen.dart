import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
  await Future.delayed(const Duration(milliseconds: 300));

  if (!mounted) return;

  // ALWAYS onboarding first..
  Navigator.pushReplacementNamed(context, '/onboarding');
}

Future<void> _finishOnboarding(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('onboarding_done', true);

  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    Navigator.pushReplacementNamed(context, '/login');
  } else {
    Navigator.pushReplacementNamed(context, '/home');
  }
}

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
