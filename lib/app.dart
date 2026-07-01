import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/env.dart';
import 'models/profile.dart';
import 'providers/providers.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_theme.dart';
import 'utils/analytics.dart';
import 'utils/startup_catalog.dart';
import 'utils/startup_warmup.dart';
import 'widgets/logo.dart';

bool _hasRestoredSupabaseSession() {
  if (!Env.hasSupabaseCredentials) return false;
  return Supabase.instance.client.auth.currentSession != null;
}

class TrackPepperApp extends ConsumerWidget {
  const TrackPepperApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isConfigured) {
      return MaterialApp(
        title: 'TrackPepper',
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: const _ConfigErrorScreen(
          message: 'Supabase is not configured.\n\n'
              'Copy dart_defines.example.json to dart_defines.json '
              'and add your credentials, then run:\n'
              'flutter run --dart-define-from-file=dart_defines.json',
        ),
      );
    }

    final authState = ref.watch(authStateProvider);
    final pendingPasswordRecovery = ref.watch(pendingPasswordRecoveryProvider);

    ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) {
      next.whenData((state) {
        if (state.event == AuthChangeEvent.passwordRecovery) {
          ref.read(pendingPasswordRecoveryProvider.notifier).state = true;
        }
        _syncAnalyticsIdentity(ref, state.session?.user.id);
      });
    });

    ref.listen<AsyncValue<Profile?>>(profileProvider, (previous, next) {
      next.whenData((profile) {
        writeHasHouseholdHint(profile?.hasHousehold ?? false);
        final userId = authState.maybeWhen(
          data: (state) => state.session?.user.id,
          orElse: () => null,
        );
        if (userId != null) {
          Analytics.setAnalyticsUser(
            userId,
            hasHousehold: profile?.householdId != null,
            householdId: profile?.activeHouseholdId ?? profile?.householdId,
          );
        }
      });
    });

    final sessionUserId = authState.maybeWhen(
      data: (state) => state.session?.user.id,
      orElse: () => null,
    );

    return MaterialApp(
      // Reset the navigator when auth changes (e.g. sign out from a pushed route).
      key: ValueKey(sessionUserId ?? 'logged-out'),
      title: 'TrackPepper',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: authState.when(
              loading: () => _hasRestoredSupabaseSession()
                  ? const _AuthenticatedRouter()
                  : const _StartupSplashScreen(),
              error: (e, _) => _ConfigErrorScreen(message: e.toString()),
              data: (state) {
                final session = state.session;
                if (pendingPasswordRecovery && session != null) {
                  return ResetPasswordScreen(
                    onComplete: () {
                      ref.read(pendingPasswordRecoveryProvider.notifier).state = false;
                      ref.invalidate(profileProvider);
                    },
                  );
                }
                if (session == null) {
                  ref.read(pendingPasswordRecoveryProvider.notifier).state = false;
                  return const AuthScreen();
                }

                return const _AuthenticatedRouter();
              },
            ),
    );
  }
}

void _syncAnalyticsIdentity(WidgetRef ref, String? userId) {
  if (userId == null) {
    Analytics.setAnalyticsUser(null);
    return;
  }

  ref.read(profileProvider.future).then((profile) {
    Analytics.setAnalyticsUser(
      userId,
      hasHousehold: profile?.householdId != null,
      householdId: profile?.activeHouseholdId ?? profile?.householdId,
    );
  });
}

class _AuthenticatedRouter extends ConsumerWidget {
  const _AuthenticatedRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const _StartupSplashScreen(prefetchCatalog: true),
      error: (e, _) => _ConfigErrorScreen(message: e.toString()),
      data: (profile) {
        if (profile == null || !profile.hasHousehold) {
          return const OnboardingScreen();
        }
        return const CalendarScreen();
      },
    );
  }
}

class _StartupSplashScreen extends ConsumerStatefulWidget {
  const _StartupSplashScreen({this.prefetchCatalog = false});

  final bool prefetchCatalog;

  @override
  ConsumerState<_StartupSplashScreen> createState() => _StartupSplashScreenState();
}

class _StartupSplashScreenState extends ConsumerState<_StartupSplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        StartupWarmup.run(
          ref,
          context,
          prefetchCatalog: widget.prefetchCatalog,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.light.scaffoldBackgroundColor,
      body: const Center(
        child: Logo(variant: LogoVariant.brand),
      ),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Logo(variant: LogoVariant.brand),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: AppFonts.sz(14), height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
