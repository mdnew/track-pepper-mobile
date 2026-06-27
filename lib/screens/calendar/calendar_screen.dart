import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/pet.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/species_theme.dart';
import '../../utils/pet_age.dart';
import '../../utils/pet_selection.dart';
import '../../widgets/completion_indicator.dart';
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
  Map<DateTime, int> _completionCounts = {};
  int _taskCount = 0;
  String? _selectedPetId;
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
    _init();
  }

  Future<void> _init() async {
    _selectedPetId = await readSelectedPetId();
    await _loadData();
  }

  Future<void> _loadData() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.householdId == null) return;

    final pets = await ref.read(petsProvider.future);
    final petId = resolveSelectedPetId(pets, preferredId: _selectedPetId);
    final pet = _petForId(pets, petId);

    if (petId != null) {
      await writeSelectedPetId(petId);
    }

    if (mounted) {
      setState(() {
        _selectedPetId = petId;
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
    await writeSelectedPetId(pet.id);
    if (!mounted) return;
    setState(() => _selectedPetId = pet.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayScreen(date: _normalize(day), pet: pet),
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
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final petsAsync = ref.watch(petsProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (profile) {
        final pets = petsAsync.valueOrNull ?? const [];
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
                  if (pets.length > 1) ...[
                    _PetSelector(
                      pets: pets,
                      selectedPetId: pet?.id,
                      theme: theme,
                      onSelect: (petId) async {
                        await writeSelectedPetId(petId);
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
    if (pets.length <= 1 || selectedPetId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.introBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedPetId,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: theme.textSecondary),
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          dropdownColor: theme.card,
          items: [
            for (final pet in pets)
              DropdownMenuItem(
                value: pet.id,
                child: Text(formatPetSummary(pet)),
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
