import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text_styles.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/household_role.dart';
import '../../models/household_membership.dart';
import '../../models/pet.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/species_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/household_selection.dart';
import '../../utils/local_catalog_cache.dart';
import '../../utils/perf_log.dart';
import '../../utils/pet_age.dart';
import '../../utils/pet_selection.dart';
import '../../utils/startup_catalog.dart';
import '../../widgets/completion_indicator.dart';
import '../../widgets/emoji_text.dart';
import '../../widgets/household_selector.dart';
import '../../widgets/logo.dart';
import '../day/day_screen.dart';
import '../settings/settings_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  String? _activeHouseholdId;
  List<HouseholdMembership> _memberships = const [];
  Map<String, List<Pet>> _petsByHouseholdId = const {};
  Map<DateTime, int> _completionCounts = const {};
  Map<DateTime, int> _dayTotals = const {};
  bool _loading = true;
  int _completionRequestId = 0;

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Pet> get _activePets => _activeHouseholdId == null
      ? const <Pet>[]
      : (_petsByHouseholdId[_activeHouseholdId!] ?? const <Pet>[]);

  @override
  void initState() {
    super.initState();
    _seedFromStartupCatalog();
    Analytics.trackPageView('/');
    unawaited(_loadData());
  }

  void _seedFromStartupCatalog() {
    final cached = StartupCatalog.snapshot;
    final storedHouseholdId = StartupCatalog.storedHouseholdId;

    if (cached != null) {
      final activeHouseholdId = cached.activeHouseholdId ??
          storedHouseholdId ??
          (cached.memberships.isNotEmpty
              ? cached.memberships.first.household.id
              : null);
      final hasCachedPets = activeHouseholdId != null &&
          (cached.petsByHousehold[activeHouseholdId]?.isNotEmpty ?? false);

      _activeHouseholdId = activeHouseholdId;
      _memberships = cached.memberships;
      _petsByHouseholdId = cached.petsByHousehold;
      _loading = !hasCachedPets;
      return;
    }

    if (storedHouseholdId != null) {
      _activeHouseholdId = storedHouseholdId;
      _loading = true;
    }
  }

  Future<String?> _resolveActiveHouseholdId(
    List<HouseholdMembership> memberships,
  ) async {
    if (_activeHouseholdId != null &&
        memberships.any((m) => m.household.id == _activeHouseholdId)) {
      return _activeHouseholdId;
    }

    final stored = await readActiveHouseholdId();
    final profile = await ref.read(profileProvider.future);
    final authService = ref.read(authServiceProvider);
    return resolveActiveHouseholdId(
      memberships.map((m) => m.household.id).toList(),
      preferredId: stored,
      profileActiveId: authService.resolveActiveHouseholdId(profile),
    );
  }

  Future<void> _loadData({bool force = false}) async {
    return PerfLog.time('CalendarScreen._loadData', () async {
      if (!mounted) return;

      if (!force && _activePets.isNotEmpty) {
        _scheduleDeferredStartupWork();
        unawaited(_refreshPetsFromNetwork());
        return;
      }

      setState(() => _loading = true);

      try {
        final memberships = force || _memberships.isEmpty
            ? await ref.read(membershipsProvider.future)
            : _memberships;
        final activeHouseholdId = force
            ? await _resolveActiveHouseholdId(memberships)
            : (_activeHouseholdId ?? await _resolveActiveHouseholdId(memberships));

        if (!mounted) return;
        if (activeHouseholdId == null || memberships.isEmpty) {
          setState(() => _loading = false);
          return;
        }

        final petsByHousehold = await _fetchPetsByHousehold(memberships);
        if (!mounted) return;

        setState(() {
          _memberships = memberships;
          _activeHouseholdId = activeHouseholdId;
          _petsByHouseholdId = petsByHousehold;
          _loading = false;
        });

        unawaited(
          writeLocalCatalogCache(
            memberships: memberships,
            petsByHousehold: petsByHousehold,
            activeHouseholdId: activeHouseholdId,
          ),
        );
        _scheduleDeferredStartupWork();
      } catch (_) {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    });
  }

  Future<Map<String, List<Pet>>> _fetchPetsByHousehold(
    List<HouseholdMembership> memberships,
  ) async {
    final petsService = ref.read(petsServiceProvider);
    final entries = await Future.wait(
      memberships.map((membership) async {
        final pets = await petsService.getPets(householdId: membership.household.id);
        return MapEntry(membership.household.id, pets);
      }),
    );
    return Map.fromEntries(entries);
  }

  Future<void> _refreshPetsFromNetwork() async {
    if (!mounted) return;

    try {
      final memberships = await ref.read(membershipsProvider.future);
      final activeHouseholdId = await _resolveActiveHouseholdId(memberships);
      if (!mounted || activeHouseholdId == null || memberships.isEmpty) return;

      final petsByHousehold = await _fetchPetsByHousehold(memberships);
      if (!mounted) return;

      setState(() {
        _memberships = memberships;
        _activeHouseholdId = activeHouseholdId;
        _petsByHouseholdId = petsByHousehold;
        _loading = false;
      });

      unawaited(
        writeLocalCatalogCache(
          memberships: memberships,
          petsByHousehold: petsByHousehold,
          activeHouseholdId: activeHouseholdId,
        ),
      );
    } catch (_) {}
  }

  void _scheduleDeferredStartupWork() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadCompletionStatus());
      unawaited(_prefetchTodaySchedule());
    });
  }

  Future<void> _prefetchTodaySchedule() async {
    return PerfLog.time('CalendarScreen._prefetchTodaySchedule', () async {
      final householdId = _activeHouseholdId;
      final pets = _activePets;
      if (householdId == null || pets.isEmpty) return;

      final storedPetId = await readSelectedPetId(householdId: householdId);
      final petId = resolveSelectedPetId(pets, preferredId: storedPetId);
      if (petId == null) return;
      final selectedPet = pets.where((pet) => pet.id == petId).firstOrNull;
      if (selectedPet == null) return;

      final scheduleService = ref.read(scheduleServiceProvider);
      final today = DateTime.now();
      try {
        final plans = await scheduleService.getPlans();
        await Future.wait([
          scheduleService.getScheduleForPet(
            pet: selectedPet,
            plans: plans,
            referenceDate: today,
          ),
          scheduleService.getCompletionsForDate(
            householdId: householdId,
            petId: selectedPet.id,
            date: today,
          ),
        ]);
      } catch (_) {}
    });
  }

  Future<void> _loadActiveHouseholdPets(String householdId) async {
    final pets = await ref.read(petsServiceProvider).getPets(householdId: householdId);
    if (!mounted) return;
    setState(() {
      _activeHouseholdId = householdId;
      _petsByHouseholdId = {
        ..._petsByHouseholdId,
        householdId: pets,
      };
      _loading = false;
    });
    _scheduleDeferredStartupWork();
  }

  Future<void> _loadCompletionStatus() async {
    return PerfLog.time('CalendarScreen._loadCompletionStatus', () async {
      final householdId = _activeHouseholdId;
      final pets = _activePets;
      final requestId = ++_completionRequestId;

      if (householdId == null || pets.isEmpty) {
        if (!mounted || requestId != _completionRequestId) return;
        setState(() {
          _completionCounts = const {};
          _dayTotals = const {};
        });
        return;
      }

      try {
        final scheduleService = ref.read(scheduleServiceProvider);
        final plans = await scheduleService.getPlans();
        if (!mounted || requestId != _completionRequestId) return;

        final result = await scheduleService.getAggregatedCountsForMonth(
          householdId: householdId,
          pets: pets,
          plans: plans,
          month: _focusedDay,
        );
        if (!mounted || requestId != _completionRequestId) return;

        setState(() {
          _completionCounts = result.completions;
          _dayTotals = result.totals;
        });
      } catch (_) {
        if (!mounted || requestId != _completionRequestId) return;
        setState(() {
          _completionCounts = const {};
          _dayTotals = const {};
        });
      }
    });
  }

  Future<void> _openDay(DateTime day) async {
    PerfLog.markTap('CalendarScreen tap ${formatDateKey(_normalize(day))}');
    final householdId = _activeHouseholdId;
    if (householdId == null) return;
    final pets = _activePets;
    if (pets.isEmpty) return;

    final normalized = _normalize(day);
    final petId = resolveSelectedPetId(pets);

    HouseholdRole? initialRole;
    final memberships = ref.read(membershipsProvider).valueOrNull;
    if (memberships != null) {
      for (final membership in memberships) {
        if (membership.household.id == householdId) {
          initialRole = membership.role;
          break;
        }
      }
    }

    PerfLog.markFromTap('CalendarScreen pushing DayScreen');
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => DayScreen(
          date: normalized,
          householdId: householdId,
          initialPetId: petId,
          initialPets: pets,
          initialRole: initialRole,
        ),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    if (!mounted) return;
    _loadCompletionStatus();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    ref.read(scheduleServiceProvider).invalidateScheduleCache();
    ref.invalidate(profileProvider);
    ref.invalidate(membershipsProvider);
    ref.invalidate(activeHouseholdIdProvider);
    await _loadData(force: true);
  }

  Future<void> _selectHousehold(String householdId) async {
    if (_activeHouseholdId == householdId) return;

    await ref.read(authServiceProvider).setActiveHousehold(householdId);
    ref.invalidate(activeHouseholdIdProvider);

    final cachedPets = _petsByHouseholdId[householdId];
    setState(() {
      _activeHouseholdId = householdId;
      _completionCounts = const {};
      _dayTotals = const {};
      _loading = cachedPets == null || cachedPets.isEmpty;
    });

    if (cachedPets != null && cachedPets.isNotEmpty) {
      _scheduleDeferredStartupWork();
    } else {
      await _loadActiveHouseholdPets(householdId);
    }
  }

  Widget _dayCellBuilder(BuildContext context, DateTime day, DateTime focusedDay) {
    final normalized = _normalize(day);
    return _DayCell(
      day: day.day,
      isToday: isSameDay(day, DateTime.now()),
      isOutside: day.month != focusedDay.month,
      completed: _completionCounts[normalized] ?? 0,
      total: _dayTotals[normalized] ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(scheduleRevisionProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.read(scheduleServiceProvider).invalidateScheduleCache();
      unawaited(_loadCompletionStatus());
    });

    final pets = _activePets;
    final theme = speciesTheme(PetSpecies.dog);
    final petsLine = formatCalendarPetNamesLine(pets);
    final showEmptyState = !_loading && pets.isEmpty;
    final showCalendar = pets.isNotEmpty;

    if (_loading && pets.isEmpty) {
      return Scaffold(
        backgroundColor: AppTheme.light.scaffoldBackgroundColor,
        body: const Center(
          child: Logo(variant: LogoVariant.brand),
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: theme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: theme.header,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(color: theme.card),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Logo(variant: LogoVariant.header),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              onPressed: _openSettings,
              tooltip: 'Profile & household',
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _loadData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_memberships.length > 1) ...[
                HouseholdSelector(
                  memberships: _memberships,
                  selectedHouseholdId: _activeHouseholdId,
                  petsByHouseholdId: _petsByHouseholdId,
                  showPetNames: false,
                  onSelect: _selectHousehold,
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (showEmptyState)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Add your first pet in Settings to unlock age-based dog and cat schedules.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.textSecondary, height: 1.5),
                          ),
                        )
                      else if (showCalendar) ...[
                        if (petsLine != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: EmojiAwareText(
                              petsLine,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: AppFonts.sz(13),
                                fontWeight: FontWeight.w600,
                                color: theme.textSecondary,
                              ),
                            ),
                          ),
                        TableCalendar<void>(
                          firstDay: DateTime.utc(2025, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (_) => false,
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          rowHeight: 56,
                          daysOfWeekHeight: 32,
                          pageAnimationEnabled: false,
                          onDaySelected: (selected, focused) {
                            if (pets.isEmpty) return;
                            setState(() => _focusedDay = focused);
                            _openDay(selected);
                          },
                          onPageChanged: (focused) {
                            setState(() {
                              _focusedDay = focused;
                              _completionCounts = const {};
                              _dayTotals = const {};
                            });
                            _loadCompletionStatus();
                          },
                          calendarStyle: CalendarStyle(
                            cellMargin: const EdgeInsets.all(6),
                            outsideDaysVisible: true,
                            defaultTextStyle: const TextStyle(fontSize: 0),
                            weekendTextStyle: const TextStyle(fontSize: 0),
                            todayTextStyle: const TextStyle(fontSize: 0),
                            selectedTextStyle: const TextStyle(fontSize: 0),
                            todayDecoration: BoxDecoration(),
                            selectedDecoration: BoxDecoration(),
                          ),
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            titleTextStyle: AppFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: AppFonts.sz(16),
                              color: theme.textPrimary,
                            ),
                            formatButtonVisible: false,
                          ),
                          calendarBuilders: CalendarBuilders(
                            defaultBuilder: _dayCellBuilder,
                            todayBuilder: _dayCellBuilder,
                            selectedBuilder: _dayCellBuilder,
                            outsideBuilder: _dayCellBuilder,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap a day to view and check off tasks',
                          style: TextStyle(
                            fontSize: AppFonts.sz(12),
                            color: theme.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    this.isToday = false,
    this.isOutside = false,
    this.completed = 0,
    this.total = 0,
  });

  final int day;
  final bool isToday;
  final bool isOutside;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textColor = isOutside
        ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.45)
        : isToday
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).textTheme.bodyLarge?.color;

    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                  : null,
              border: isToday
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: textColor,
                fontSize: AppFonts.sz(15),
              ),
            ),
          ),
          CompletionIndicator(
            completed: completed,
            total: total,
            size: 20,
            compact: true,
          ),
        ],
      ),
    );
  }
}
