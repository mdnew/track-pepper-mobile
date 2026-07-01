import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import '../models/household_membership.dart';
import '../models/pet.dart';
import '../models/schedule_task.dart';
import '../providers/providers.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/species_theme.dart';
import '../utils/perf_log.dart';
import '../utils/pet_selection.dart';
import '../widgets/emoji_text.dart';
import '../widgets/schedule_block.dart';
import '../widgets/section_divider.dart';
import 'startup_catalog.dart';

const _warmupTask = ScheduleTask(
  id: '_warmup_task',
  planId: 'dog_young_puppy',
  sortOrder: 0,
  timeLabel: '8:00 AM',
  category: 'feed',
  title: 'Warmup task',
  subtitle: 'Pre-renders fonts and widgets during splash.',
  icon: '🍼',
  section: 'Morning',
);

/// Work done while the splash logo is visible so first navigation feels instant.
abstract final class StartupWarmup {
  static bool _uiWarmed = false;

  static Future<void> run(WidgetRef ref, BuildContext context,
      {bool prefetchCatalog = false}) async {
    await PerfLog.time('StartupWarmup.run', () async {
      await Future.wait([
        _warmUiWhenReady(context),
        if (prefetchCatalog) prefetchAuthCatalog(ref),
      ]);
    });
  }

  static Future<void> _warmUiWhenReady(BuildContext context) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return;
    await warmUiAfterFirstFrame(context);
  }

  /// Downloads and caches Nunito + emoji before any screen builds text.
  static Future<void> prefetchAuthCatalog(WidgetRef ref) async {
    if (!Env.hasSupabaseCredentials) return;
    if (Supabase.instance.client.auth.currentSession == null) return;

    await PerfLog.time('StartupWarmup.prefetchAuthCatalog', () async {
      await Future.wait([
        ref.read(membershipsProvider.future).catchError(
              (_) => <HouseholdMembership>[],
            ),
        prefetchTodaySchedule(ref),
      ]);
    });
  }

  static Future<void> prefetchTodaySchedule(WidgetRef ref) async {
    final snapshot = StartupCatalog.snapshot;
    if (snapshot == null) return;

    final householdId =
        snapshot.activeHouseholdId ?? StartupCatalog.storedHouseholdId;
    if (householdId == null) return;

    final pets = snapshot.petsByHousehold[householdId];
    if (pets == null || pets.isEmpty) return;

    final petId = resolveSelectedPetId(pets);
    final pet = petId == null
        ? null
        : pets.where((item) => item.id == petId).firstOrNull;
    if (pet == null) return;

    final scheduleService = ref.read(scheduleServiceProvider);
    final today = DateTime.now();
    final normalized = DateTime(today.year, today.month, today.day);
    final plans = await scheduleService.getPlans();
    await scheduleService.getScheduleForPet(
      pet: pet,
      plans: plans,
      referenceDate: normalized,
    );
    await scheduleService.getCompletionsForDate(
      householdId: householdId,
      petId: pet.id,
      date: normalized,
    );
  }

  /// Builds day-screen widgets offstage so the first real navigation reuses caches.
  static Future<void> warmUiAfterFirstFrame(BuildContext context) async {
    if (_uiWarmed) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final theme = speciesTheme(PetSpecies.dog);
        return Offstage(
          child: Material(
            color: AppColors.background,
            child: SizedBox(
              width: 390,
              height: 844,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppBar(title: const Text('Warmup')),
                  SectionDivider(label: 'Morning', color: theme.divider),
                  ScheduleBlock(
                    task: _warmupTask,
                    species: PetSpecies.dog,
                    theme: theme,
                  ),
                  const EmojiText('🍼'),
                  Text(
                    'TrackPepper',
                    style: AppFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: AppFonts.sz(15),
                    ),
                  ),
                  Checkbox(value: false, onChanged: (_) {}),
                  OutlinedButton(onPressed: () {}, child: const Text('Mark All')),
                  const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    entry.remove();
    _uiWarmed = true;
    PerfLog.mark('StartupWarmup.uiLayers warmed');
  }
}
