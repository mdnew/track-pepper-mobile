import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/species_theme.dart';
import '../../utils/pet_age.dart';
import '../../utils/schedule_plan.dart';
import '../../widgets/completion_indicator.dart';
import '../day/day_screen.dart';
import '../settings/settings_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, int> _completionCounts = {};
  int _taskCount = 0;
  String? _selectedPetId;
  bool _loading = true;

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Pet? _selectedPet(List<Pet> pets) {
    if (pets.isEmpty) return null;
    if (_selectedPetId != null) {
      for (final candidate in pets) {
        if (candidate.id == _selectedPetId) return candidate;
      }
    }
    return pets.first;
  }

  Future<void> _loadData() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.householdId == null) return;

    final pets = await ref.read(petsProvider.future);
    final pet = _selectedPet(pets);
    if (pet != null && _selectedPetId == null) {
      _selectedPetId = pet.id;
    }

    setState(() => _loading = true);
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final plans = await scheduleService.getPlans();
      final schedule = pet != null
          ? await scheduleService.getScheduleForPet(
              pet: pet,
              plans: plans,
            )
          : (plan: null, tasks: <ScheduleTask>[]);
      final counts = pet != null
          ? await scheduleService.getCompletionCountsForMonth(
              householdId: profile!.householdId!,
              petId: pet.id,
              month: _focusedDay,
            )
          : <DateTime, int>{};

      if (mounted) {
        setState(() {
          _taskCount = schedule.tasks.length;
          _completionCounts = counts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDay(DateTime day, Pet pet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayScreen(date: _normalize(day), pet: pet),
      ),
    );
    await _loadData();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    ref.invalidate(profileProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(petsProvider);
    await _loadData();
  }

  int _countForDay(DateTime day) {
    return _completionCounts[_normalize(day)] ?? 0;
  }

  Widget _dayCellBuilder(BuildContext context, DateTime day, DateTime focusedDay) {
    final count = _countForDay(day);
    final isToday = isSameDay(day, DateTime.now());
    final isOutside = day.month != focusedDay.month;

    return _DayCell(
      day: day.day,
      completed: count,
      total: _taskCount,
      isToday: isToday,
      isOutside: isOutside,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final householdAsync = ref.watch(householdProvider);
    final petsAsync = ref.watch(petsProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (profile) {
        final pets = petsAsync.valueOrNull ?? const [];
        final pet = _selectedPet(pets);
        final theme = speciesTheme(pet?.species ?? PetSpecies.dog);
        final plansFuture = ref.read(scheduleServiceProvider).getPlans();

        return FutureBuilder<List<SchedulePlan>>(
          future: plansFuture,
          builder: (context, planSnapshot) {
            final plan = pet != null && planSnapshot.hasData
                ? resolvePlanForPet(planSnapshot.data!, pet)
                : null;

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
                  title: const Text('TrackPepper'),
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
                      _HeaderCard(
                        theme: theme,
                        householdName: householdAsync.valueOrNull?.name,
                        pet: pet,
                        planName: plan?.name,
                        profileName: profile?.displayName,
                      ),
                      if (pets.length > 1) ...[
                        const SizedBox(height: 12),
                        _PetSelector(
                          pets: pets,
                          selectedPetId: pet?.id,
                          theme: theme,
                          onSelect: (petId) {
                            setState(() => _selectedPetId = petId);
                            _loadData();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
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
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      height: 1.5,
                                    ),
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
                                  calendarStyle: CalendarStyle(
                                    cellMargin: const EdgeInsets.all(6),
                                    outsideDaysVisible: true,
                                    defaultTextStyle: const TextStyle(fontSize: 0),
                                    weekendTextStyle: const TextStyle(fontSize: 0),
                                    todayTextStyle: const TextStyle(fontSize: 0),
                                    selectedTextStyle: const TextStyle(fontSize: 0),
                                    todayDecoration: const BoxDecoration(),
                                    selectedDecoration: const BoxDecoration(),
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
          },
        );
      },
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.theme,
    this.householdName,
    this.pet,
    this.planName,
    this.profileName,
  });

  final SpeciesTheme theme;
  final String? householdName;
  final Pet? pet;
  final String? planName;
  final String? profileName;

  @override
  Widget build(BuildContext context) {
    final subtitle = pet != null
        ? '${formatPetSummary(pet!)}${planName != null ? ' · $planName' : ''}'
        : 'Add a pet in Settings to get a personalized schedule';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.header,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(pet != null ? theme.emoji : '🐾', style: const TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  householdName ?? 'Daily Schedule',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: theme.headerSubtitle),
                ),
                if (profileName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Signed in as $profileName',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedPetId,
    required this.theme,
    required this.onSelect,
  });

  final List<Pet> pets;
  final String? selectedPetId;
  final SpeciesTheme theme;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final pet in pets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(formatPetSummary(pet)),
                selected: pet.id == selectedPetId,
                onSelected: (_) => onSelect(pet.id),
                selectedColor: theme.divider,
                backgroundColor: theme.card,
                labelStyle: TextStyle(
                  color: pet.id == selectedPetId
                      ? (theme.species == PetSpecies.cat
                          ? const Color(0xFF0D0D1A)
                          : Colors.white)
                      : theme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                side: BorderSide(color: theme.introBorder),
              ),
            ),
        ],
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
