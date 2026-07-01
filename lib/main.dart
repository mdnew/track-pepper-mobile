import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/env.dart';
import 'theme/app_text_styles.dart';
import 'utils/analytics.dart';
import 'utils/app_shader_warmup.dart';
import 'utils/perf_log.dart';
import 'utils/startup_catalog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.shaderWarmUp = const AppShaderWarmUp();

  if (Env.hasSupabaseCredentials) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey, // ignore: deprecated_member_use
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  await Future.wait([
    PerfLog.time('StartupCatalog.preload', StartupCatalog.preload),
    PerfLog.time('AppFonts.preloadAllFonts', AppFonts.preloadAllFonts),
  ]);

  runApp(const ProviderScope(child: TrackPepperApp()));

  unawaited(_deferredInit());
}

Future<void> _deferredInit() async {
  try {
    await Firebase.initializeApp();
    await Analytics.init();
  } catch (_) {
    // Analytics is optional for app function.
  }
}
