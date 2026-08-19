import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/config/env.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/auth/auth_repository.dart';
import 'package:stericord_mobile/routes/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const SteriCordApp());
}

class SteriCordApp extends StatelessWidget {
  const SteriCordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(AuthRepository()),
      child: const AppRouterScope(),
    );
  }
}
