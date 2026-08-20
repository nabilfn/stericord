import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/config/env.dart';
import 'package:stericord_mobile/core/offline/sync_service.dart';
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

class SteriCordApp extends StatefulWidget {
  const SteriCordApp({super.key});

  @override
  State<SteriCordApp> createState() => _SteriCordAppState();
}

class _SteriCordAppState extends State<SteriCordApp> {
  final _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    _syncService.start();
    // Drain immediately at launch too, in case operations were queued
    // during a previous offline session and connectivity is already back
    // by the time the app is reopened -- not just on the next connectivity
    // change event.
    _syncService.drainQueue();
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController(AuthRepository())),
        Provider<SyncService>.value(value: _syncService),
      ],
      child: const AppRouterScope(),
    );
  }
}
