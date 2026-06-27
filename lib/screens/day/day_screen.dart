import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/completion.dart';
import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/species_theme.dart';
import '../../utils/pet_selection.dart';
import '../../utils/schedule_time.dart';
import '../../utils/analytics.dart';
import '../../config/recommendations.dart';
import '../../widgets/recommendations_section.dart';
import '../../widgets/schedule_block.dart';
import '../../widgets/section_divider.dart';

class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, required this.date, required this.pet});

  final DateTime date;
  final Pet pet;

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  SchedulePlan? _plan;
  List<ScheduleTask> _tasks = [];
  Map<String, Completion> _completions = {};
  final Set<String> _loadingTasks = {};
  bool _loading = true;
  bool _markingAll = false;
  bool _hasAutoScrolled = false;
  RealtimeChannel? _channel;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowLineKey = GlobalKey();
  final GlobalKey _scrollAnchorKey = GlobalKey();
  final GlobalKey _currentSlotKey = GlobalKey();

  bool get _isToday => isSameCalendarDay(widget.date, DateTime.now());

  SpeciesTheme get _theme => speciesTheme(widget.pet.species);

  @override
  void initState() {
    super.initState();
    writeSelectedPetId(widget.pet.id);
    Analytics.trackPageView('/day/${formatDateKey(widget.date)}');
    _load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.householdId == null) return;

    setState(() => _loading = true);
    try {
      final scheduleService = ref.read(scheduleServiceProvider);
      final plans = await scheduleService.getPlans();
      final schedule = await scheduleService.getScheduleForPet(
        pet: widget.pet,
        plans: plans,
        referenceDate: widget.date,
      );
      final completions = await scheduleService.getCompletionsForDate(
        householdId: profile!.householdId!,
        petId: widget.pet.id,
        date: widget.date,
      );

      _channel?.unsubscribe();
      _channel = scheduleService.subscribeToCompletions(
        householdId: profile.householdId!,
        petId: widget.pet.id,
        date: widget.date,
        onChange: () => _refreshCompletions(),
      );

      if (mounted) {
        setState(() {
          _plan = schedule.plan;
          _tasks = sortTasksChronologically(schedule.tasks);
          _completions = {for (final c in completions) c.taskId: c};
          _loading = false;
        });
        if (_isToday && !_hasAutoScrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasAutoScrolled) _scrollToCurrentTime();
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCompletions() async {
    final profile = await ref.read(profileProvider.future);
    if (profile?.householdId == null || !mounted) return;

    final completions = await ref.read(scheduleServiceProvider).getCompletionsForDate(
          householdId: profile!.householdId!,
          petId: widget.pet.id,
          date: widget.date,
        );
    if (mounted) {
      setState(() {
        _completions = {for (final c in completions) c.taskId: c};
      });
    }
  }

  Future<void> _toggleTask(ScheduleTask task, bool completed) async {
    final profile = await ref.read(profileProvider.future);
    final user = ref.read(authServiceProvider).currentUser;
    if (profile?.householdId == null || user == null) return;

    setState(() => _loadingTasks.add(task.id));
    try {
      final service = ref.read(scheduleServiceProvider);
      if (completed) {
        await service.completeTask(
          householdId: profile!.householdId!,
          petId: widget.pet.id,
          taskId: task.id,
          date: widget.date,
          userId: user.id,
        );
        Analytics.trackTaskComplete(
          taskId: task.id,
          category: task.category,
          section: task.section,
          date: formatDateKey(widget.date),
          isToday: _isToday,
        );
      } else {
        await service.uncompleteTask(
          householdId: profile!.householdId!,
          petId: widget.pet.id,
          taskId: task.id,
          date: widget.date,
        );
      }
      await _refreshCompletions();
    } finally {
      if (mounted) setState(() => _loadingTasks.remove(task.id));
    }
  }

  Future<void> _markAllCompleted() async {
    if (_markingAll) return;

    final profile = await ref.read(profileProvider.future);
    final user = ref.read(authServiceProvider).currentUser;
    if (profile?.householdId == null || user == null) return;

    final incompleteTaskIds = _tasks
        .where((task) => !_completions.containsKey(task.id))
        .map((task) => task.id)
        .toList();
    if (incompleteTaskIds.isEmpty) return;

    setState(() => _markingAll = true);
    try {
      await ref.read(scheduleServiceProvider).completeAllTasks(
            householdId: profile!.householdId!,
            petId: widget.pet.id,
            taskIds: incompleteTaskIds,
            date: widget.date,
            userId: user.id,
          );
      await _refreshCompletions();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  void _scrollToCurrentTime() {
    if (_hasAutoScrolled) return;

    Future<void> attemptScroll(int tries) async {
      if (!mounted || tries > 20) return;

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scrollController.hasClients || _tasks.isEmpty) {
        return attemptScroll(tries + 1);
      }

      final nowIndex = currentTimeInsertIndex(_tasks, DateTime.now());
      final position = _scrollController.position;

      if (tries <= 2 && position.maxScrollExtent > 0) {
        const rowHeight = 78.0;
        final rough = ((nowIndex > 0 ? nowIndex - 1 : nowIndex) * rowHeight)
            .clamp(0.0, position.maxScrollExtent);
        if ((position.pixels - rough).abs() > 1) {
          position.jumpTo(rough);
          return attemptScroll(tries + 1);
        }
      }

      BuildContext? slotContext;
      if (_isToday) {
        slotContext = _nowLineKey.currentContext;
      } else if (nowIndex < _tasks.length) {
        slotContext = _currentSlotKey.currentContext;
      }

      if (slotContext == null) {
        if (nowIndex >= _tasks.length && tries > 4) {
          position.jumpTo(position.maxScrollExtent);
          _hasAutoScrolled = true;
        } else if (nowIndex == 0 && tries > 4) {
          position.jumpTo(0);
          _hasAutoScrolled = true;
        }
        return attemptScroll(tries + 1);
      }

      if (!slotContext.mounted) {
        return attemptScroll(tries + 1);
      }

      final slotBox = slotContext.findRenderObject();
      if (slotBox is! RenderBox || !slotBox.hasSize) {
        return attemptScroll(tries + 1);
      }

      final viewport = RenderAbstractViewport.maybeOf(slotBox);
      if (viewport == null) {
        return attemptScroll(tries + 1);
      }

      var targetOffset = viewport.getOffsetToReveal(slotBox, 0.0).offset;

      if (nowIndex > 0) {
        final prevContext = _scrollAnchorKey.currentContext;
        final prevBox = prevContext?.findRenderObject();
        if (prevBox is RenderBox && prevBox.hasSize) {
          targetOffset -= prevBox.size.height + 6;
        }
      }

      final clamped = targetOffset.clamp(0.0, position.maxScrollExtent);

      if (targetOffset > position.maxScrollExtent + 1 && tries < 18) {
        return attemptScroll(tries + 1);
      }

      if ((position.pixels - clamped).abs() > 1) {
        position.jumpTo(clamped);
      }

      _hasAutoScrolled = true;
    }

    attemptScroll(0);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat.yMMMMEEEEd().format(widget.date);
    final completedCount = _completions.length;
    final totalCount = _tasks.length;
    final allCompleted = totalCount > 0 && completedCount >= totalCount;
    final accent = _theme.progressAccent;

    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _theme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: _theme.header,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(dateLabel),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_tasks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _ProgressBanner(
                        completed: completedCount,
                        total: totalCount,
                        theme: _theme,
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ..._buildTaskList(accent),
                            if (_plan?.tipsBody != null) ...[
                              const SizedBox(height: 16),
                              _TipBox(plan: _plan!, theme: _theme),
                            ],
                            if (recommendationsForSpecies(widget.pet.species)
                                .isNotEmpty) ...[
                              const SizedBox(height: 16),
                              RecommendationsSection(
                                items: recommendationsForSpecies(
                                  widget.pet.species,
                                ),
                                compact: true,
                                theme: _theme,
                              ),
                            ],
                            if (_tasks.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: allCompleted || _markingAll
                                      ? null
                                      : _markAllCompleted,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _theme.header,
                                    side: BorderSide(color: _theme.header),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _markingAll
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _theme.header,
                                          ),
                                        )
                                      : Text(
                                          'Mark All Completed',
                                          style: GoogleFonts.nunito(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildTaskList(Color accent) {
    final widgets = <Widget>[];
    String? currentSection;
    final now = DateTime.now();
    final nowIndex = currentTimeInsertIndex(_tasks, now);
    var taskIndex = 0;

    for (final task in _tasks) {
      if (_isToday && taskIndex == nowIndex) {
        widgets.add(_CurrentTimeLine(key: _nowLineKey, time: now, accent: accent));
      }

      if (task.section != currentSection) {
        currentSection = task.section;
        widgets.add(SectionDivider(label: currentSection, color: _theme.divider));
      }
      widgets.add(
        ScheduleBlock(
          key: taskIndex == nowIndex - 1
              ? _scrollAnchorKey
              : taskIndex == nowIndex
                  ? _currentSlotKey
                  : null,
          task: task,
          species: widget.pet.species,
          theme: _theme,
          completion: _completions[task.id],
          loading: _loadingTasks.contains(task.id),
          onToggle: (v) => _toggleTask(task, v),
        ),
      );
      taskIndex++;
    }

    if (_isToday && nowIndex == _tasks.length) {
      widgets.add(_CurrentTimeLine(key: _nowLineKey, time: now, accent: accent));
    }

    return widgets;
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({super.key, required this.time, required this.accent});

  final DateTime time;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat.jm().format(time);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({
    required this.completed,
    required this.total,
    required this.theme,
  });

  final int completed;
  final int total;
  final SpeciesTheme theme;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s progress',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: theme.textPrimary,
                ),
              ),
              Text(
                '$completed / $total',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: theme.progressAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: theme.progressBg,
              color: theme.progressAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  const _TipBox({required this.plan, required this.theme});

  final SchedulePlan plan;
  final SpeciesTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.tipBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.tipBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.tipsTitle ?? 'Key Notes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            plan.tipsBody!,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.6,
              color: theme.tipText,
            ),
          ),
        ],
      ),
    );
  }
}
