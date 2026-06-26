import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
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
  List<ScheduleTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadData() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.householdId == null) return;

    setState(() => _loading = true);
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final tasks = await scheduleService.getTasks();
      final counts = await scheduleService.getCompletionCountsForMonth(
        householdId: profile!.householdId!,
        month: _focusedDay,
      );
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _completionCounts = counts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDay(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DayScreen(date: _normalize(day)),
      ),
    );
    await _loadData();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
    ref.invalidate(profileProvider);
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
      total: _tasks.length,
      isToday: isToday,
      isOutside: isOutside,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
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
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          return RefreshIndicator(
            onRefresh: _loadData,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(profileName: profile?.displayName),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (_loading)
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
                              setState(() => _focusedDay = focused);
                              _openDay(selected);
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
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({this.profileName});

  final String? profileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.header,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Text('🐶', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Puppy Daily Schedule',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '8–12 weeks • Wakeup 5:30 AM • Bedtime 9:30 PM',
                  style: TextStyle(fontSize: 12, color: AppColors.headerSubtitle),
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
        ? AppColors.textSecondary.withValues(alpha: 0.45)
        : isToday
            ? AppColors.header
            : AppColors.textPrimary;

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
              color: isToday ? AppColors.sleep.withValues(alpha: 0.35) : null,
              border: isToday
                  ? Border.all(color: AppColors.sleep, width: 2)
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
