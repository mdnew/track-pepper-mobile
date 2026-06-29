import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/household_membership.dart';
import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/species_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/pet_age.dart';
import '../../utils/pet_selection.dart';
import '../../utils/schedule_plan.dart';
import '../../widgets/completion_indicator.dart';
import '../../widgets/demo_banner.dart';
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
  Map<DateTime, int> _completionCounts = <DateTime, int>{};
  Map<DateTime, int> _totalTasksByDay = <DateTime, int>{};
  String? _selectedPetId;
  String? _activeHouseholdId;
  List<HouseholdMembership> _memberships = const [];
  Map<String, List<Pet>> _petsByHouseholdId = const {};
  Map<String, SchedulePlan?> _plansByPetId = {};
  bool _loading = true;

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Pet? _petForId(List<Pet> pets, String? petId) {
    if (pets.isEmpty) return null;
    if (petId != null) {
      for (final pet in pets) {
        if (pet.id == petId) return pet;
      }
    }
    return pets.first;
  }

  @override
  void initState() {
    super.initState();
    Analytics.trackPageView('/');
    _init();
  }

  Future<void> _init() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    final activeHouseholdId = await ref.read(activeHouseholdIdProvider.future);
    if (activeHouseholdId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final memberships = await ref.read(membershipsProvider.future);
    final petsByHousehold = await ref.read(petsByHouseholdProvider.future);
    final pets = petsByHousehold[activeHouseholdId] ?? const <Pet>[];
    final storedPetId =
        await readSelectedPetId(householdId: activeHouseholdId) ?? _selectedPetId;
    final petId = resolveSelectedPetId(pets, preferredId: storedPetId);
    final pet = _petForId(pets, petId);

    if (petId != null) {
      await writeSelectedPetId(householdId: activeHouseholdId, petId: petId);
    }

    if (mounted) {
      setState(() {
        _selectedPetId = petId;
        _activeHouseholdId = activeHouseholdId;
        _memberships = memberships;
        _petsByHouseholdId = petsByHousehold;
        _loading = true;
      });
    }
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final plans = await scheduleService.getPlans();
      final schedule = pet != null
          ? await scheduleService.getScheduleForPet(
              pet: pet,
              plans: plans,
            )
          : (plan: null, tasks: <ScheduleTask>[]);
      final plansByPetId = {
        for (final householdPet in pets)
          householdPet.id: resolvePlanForPet(plans, householdPet),
      };
      final aggregated = await scheduleService.getAggregatedCountsForMonth(
        householdId: activeHouseholdId,
        pets: pets,
        plans: plans,
        month: _focusedDay,
      );

      if (mounted) {
        setState(() {
          _completionCounts = aggregated.completions;
          _totalTasksByDay = aggregated.totals;
          _plansByPetId = plansByPetId;
          if (pet == null && schedule.tasks.isNotEmpty) {
            _totalTasksByDay[_normalize(_focusedDay)] = schedule.tasks.length;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDay(DateTime day, Pet pet) async {
    final householdId = _activeHouseholdId;
    if (householdId == null) return;
    await writeSelectedPetId(householdId: householdId, petId: pet.id);
    if (!mounted) return;
    setState(() => _selectedPetId = pet.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DayScreen(date: _normalize(day), pet: pet, householdId: householdId),
      ),
    );
    if (!mounted) return;
    await _loadData();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    ref.invalidate(profileProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(petsProvider);
    ref.invalidate(petsByHouseholdProvider);
    ref.invalidate(membershipsProvider);
    ref.invalidate(activeHouseholdIdProvider);
    await _loadData();
  }

  int _countForDay(DateTime day) {
    return _completionCounts[_normalize(day)] ?? 0;
  }

  int _totalForDay(DateTime day) {
    return _totalTasksByDay[_normalize(day)] ?? 0;
  }

  Future<void> _selectHousehold(String householdId) async {
    if (_activeHouseholdId == householdId) return;
    await ref.read(authServiceProvider).setActiveHousehold(householdId);
    ref.invalidate(profileProvider);
    ref.invalidate(activeHouseholdIdProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(petsProvider);
    ref.invalidate(petsByHouseholdProvider);
    await _loadData();
  }

  Widget _dayCellBuilder(BuildContext context, DateTime day, DateTime focusedDay) {
    final count = _countForDay(day);
    final isToday = isSameDay(day, DateTime.now());
    final isOutside = day.month != focusedDay.month;

    return _DayCell(
      day: day.day,
      completed: count,
      total: _totalForDay(day),
      isToday: isToday,
      isOutside: isOutside,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pets = _activeHouseholdId == null
        ? const <Pet>[]
        : (_petsByHouseholdId[_activeHouseholdId!] ?? const <Pet>[]);
    final pet = _petForId(pets, _selectedPetId);
    final theme = speciesTheme(pet?.species ?? PetSpecies.dog);

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
            padding: const EdgeInsets.all(16),
            children: [
              const DemoBanner(),
              if (_memberships.isNotEmpty) ...[
                HouseholdSelector(
                  memberships: _memberships,
                  selectedHouseholdId: _activeHouseholdId,
                  petsByHouseholdId: _petsByHouseholdId,
                  onSelect: _selectHousehold,
                ),
                const SizedBox(height: 16),
              ],
              if (pets.isNotEmpty) ...[
                _PetSelector(
                  pets: pets,
                  selectedPetId: pet?.id,
                  plansByPetId: _plansByPetId,
                  theme: theme,
                  onSelect: (petId) async {
                    final householdId = _activeHouseholdId;
                    if (householdId == null) return;
                    await writeSelectedPetId(
                      householdId: householdId,
                      petId: petId,
                    );
                    setState(() => _selectedPetId = petId);
                    await _loadData();
                  },
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      if (pets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Add your first pet in Settings to unlock age-based dog and cat schedules.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.textSecondary, height: 1.5),
                          ),
                        )
                      else if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        )
                      else
                        TableCalendar<void>(
                          firstDay: DateTime.utc(2025, 1, 1),
                          lastDay: DateTime.utc(2030, 12, 31),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (_) => false,
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.sunday,
                          rowHeight: 68,
                          daysOfWeekHeight: 32,
                          onDaySelected: (selected, focused) {
                            if (pet == null) return;
                            setState(() => _focusedDay = focused);
                            _openDay(selected, pet);
                          },
                          onPageChanged: (focused) {
                            setState(() => _focusedDay = focused);
                            _loadData();
                          },
                          calendarStyle: const CalendarStyle(
                            cellMargin: EdgeInsets.all(6),
                            outsideDaysVisible: true,
                            defaultTextStyle: TextStyle(fontSize: 0),
                            weekendTextStyle: TextStyle(fontSize: 0),
                            todayTextStyle: TextStyle(fontSize: 0),
                            selectedTextStyle: TextStyle(fontSize: 0),
                            todayDecoration: BoxDecoration(),
                            selectedDecoration: BoxDecoration(),
                          ),
                          headerStyle: HeaderStyle(
                            titleCentered: true,
                            titleTextStyle: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
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
                      if (pets.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tap a day to view and check off tasks',
                          style: TextStyle(
                            fontSize: 12,
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

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedPetId,
    required this.plansByPetId,
    required this.theme,
    required this.onSelect,
  });

  final List<Pet> pets;
  final String? selectedPetId;
  final Map<String, SchedulePlan?> plansByPetId;
  final SpeciesTheme theme;
  final ValueChanged<String> onSelect;

  TextStyle get _labelStyle => TextStyle(
        color: theme.textPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        height: 1.35,
      );

  @override
  Widget build(BuildContext context) {
    if (selectedPetId == null) {
      return const SizedBox.shrink();
    }

    final selectedPet = pets.firstWhere((pet) => pet.id == selectedPetId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.introBorder),
      ),
      child: pets.length <= 1
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                formatPetSummaryWithPlan(
                  selectedPet,
                  plansByPetId[selectedPet.id],
                ),
                style: _labelStyle,
              ),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedPetId,
                isExpanded: true,
                icon: Icon(Icons.expand_more, color: theme.textSecondary),
                style: _labelStyle,
                dropdownColor: theme.card,
                items: [
                  for (final pet in pets)
                    DropdownMenuItem(
                      value: pet.id,
                      child: Text(
                        formatPetSummaryWithPlan(pet, plansByPetId[pet.id]),
                      ),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) onSelect(id);
                },
              ),
            ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.completed,
    required this.total,
    this.isToday = false,
    this.isOutside = false,
  });

  final int day;
  final int completed;
  final int total;
  final bool isToday;
  final bool isOutside;

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
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          CompletionIndicator(
            completed: completed,
            total: total,
            size: 26,
          ),
        ],
      ),
    );
  }
}
