import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/completion.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/schedule_time.dart';
import '../../widgets/schedule_block.dart';
import '../../widgets/section_divider.dart';

class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({super.key, required this.date});

  final DateTime date;

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  List<ScheduleTask> _tasks = [];
  Map<String, Completion> _completions = {};
  final Set<String> _loadingTasks = {};
  bool _loading = true;
  bool _hasAutoScrolled = false;
  RealtimeChannel? _channel;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowLineKey = GlobalKey();
  final GlobalKey _scrollAnchorKey = GlobalKey();
  final GlobalKey _currentSlotKey = GlobalKey();

  bool get _isToday => isSameCalendarDay(widget.date, DateTime.now());

  @override
  void initState() {
    super.initState();
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
      final tasks = await scheduleService.getTasks();
      final completions = await scheduleService.getCompletionsForDate(
        householdId: profile!.householdId!,
        date: widget.date,
      );

      _channel?.unsubscribe();
      _channel = scheduleService.subscribeToCompletions(
        householdId: profile.householdId!,
        date: widget.date,
        onChange: () => _refreshCompletions(),
      );

      if (mounted) {
        setState(() {
          _tasks = sortTasksChronologically(tasks);
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
          taskId: task.id,
          date: widget.date,
          userId: user.id,
        );
      } else {
        await service.uncompleteTask(
          householdId: profile!.householdId!,
          taskId: task.id,
          date: widget.date,
        );
      }
      await _refreshCompletions();
    } finally {
      if (mounted) setState(() => _loadingTasks.remove(task.id));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(dateLabel),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _ProgressBanner(
                    completed: completedCount,
                    total: totalCount,
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
                          ..._buildTaskList(),
                          const SizedBox(height: 16),
                          _TipBox(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildTaskList() {
    final widgets = <Widget>[];
    String? currentSection;
    final now = DateTime.now();
    final nowIndex = currentTimeInsertIndex(_tasks, now);
    var taskIndex = 0;

    for (final task in _tasks) {
      if (_isToday && taskIndex == nowIndex) {
        widgets.add(_CurrentTimeLine(key: _nowLineKey, time: now));
      }

      if (task.section != currentSection) {
        currentSection = task.section;
        widgets.add(SectionDivider(label: currentSection));
      }
      widgets.add(
        ScheduleBlock(
          key: taskIndex == nowIndex - 1
              ? _scrollAnchorKey
              : taskIndex == nowIndex
                  ? _currentSlotKey
                  : null,
          task: task,
          completion: _completions[task.id],
          loading: _loadingTasks.contains(task.id),
          onToggle: (v) => _toggleTask(task, v),
        ),
      );
      taskIndex++;
    }

    if (_isToday && nowIndex == _tasks.length) {
      widgets.add(_CurrentTimeLine(key: _nowLineKey, time: now));
    }

    return widgets;
  }
}

class _CurrentTimeLine extends StatelessWidget {
  const _CurrentTimeLine({super.key, required this.time});

  final DateTime time;

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
              color: AppColors.train,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.train,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.train,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBanner extends StatelessWidget {
  const _ProgressBanner({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                ),
              ),
              Text(
                '$completed / $total',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.potty,
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
              backgroundColor: AppColors.pottyBg,
              color: AppColors.potty,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.feedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.feed, style: BorderStyle.solid, width: 1),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🐾 Quick Reminders',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          SizedBox(height: 6),
          Text(
            'Outside within 5–10 min of every meal, nap, and play session. '
            'Training = 5 min max. Praise every potty outside. Overnight trips '
            'should be boring on purpose — lights low, no talking beyond a calm '
            '"good girl." She\'ll drop the overnight trip around 4–5 months.',
            style: TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFF5C3A10)),
          ),
        ],
      ),
    );
  }
}
