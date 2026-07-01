import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show FramePhase;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text_styles.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/completion.dart';
import '../../models/household_role.dart';
import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/species_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/day_list_entries.dart';
import '../../utils/local_catalog_cache.dart';
import '../../utils/perf_log.dart';
import '../../utils/pet_selection.dart';
import '../../utils/schedule_plan.dart';
import '../../utils/schedule_time.dart';
import '../../widgets/emoji_text.dart';
import '../../widgets/pet_selector.dart';
import '../../widgets/schedule_block.dart';
import '../../widgets/section_divider.dart';

class DayScreen extends ConsumerStatefulWidget {
  const DayScreen({
    super.key,
    required this.date,
    required this.householdId,
    this.initialPetId,
    this.initialPets,
    this.initialPlans,
    this.initialPlan,
    this.initialTasks,
    this.initialCompletions,
    this.initialRole,
  });

  final DateTime date;
  final String householdId;
  final String? initialPetId;
  final List<Pet>? initialPets;
  final List<SchedulePlan>? initialPlans;
  final SchedulePlan? initialPlan;
  final List<ScheduleTask>? initialTasks;
  final Map<String, Completion>? initialCompletions;
  final HouseholdRole? initialRole;

  @override
  ConsumerState<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends ConsumerState<DayScreen> {
  List<Pet> _pets = const [];
  String? _selectedPetId;
  Map<String, SchedulePlan?> _plansByPetId = const {};
  SchedulePlan? _plan;
  List<ScheduleTask> _tasks = [];
  Map<String, Completion> _completions = {};
  List<SchedulePlan> _plans = const [];
  final Set<String> _loadingTasks = {};
  bool _initialLoading = true;
  bool _scheduleLoading = false;
  String? _errorMessage;
  int _loadGeneration = 0;
  bool _markingAll = false;
  bool _hasAutoScrolled = false;
  RealtimeChannel? _channel;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _nowLineKey = GlobalKey();
  final GlobalKey _scrollAnchorKey = GlobalKey();
  final GlobalKey _currentSlotKey = GlobalKey();
  int _buildCount = 0;
  int _listItemsBuiltBeforeFirstFrame = 0;
  bool _firstFrameLogged = false;
  bool _fullyRenderedLogged = false;
  bool _rasterLogged = false;

  Pet? get _selectedPet {
    if (_selectedPetId == null) return null;
    for (final pet in _pets) {
      if (pet.id == _selectedPetId) return pet;
    }
    return null;
  }

  bool get _isToday => isSameCalendarDay(widget.date, DateTime.now());

  SpeciesTheme get _theme => speciesTheme(_selectedPet?.species ?? PetSpecies.dog);

  @override
  void initState() {
    PerfLog.markFromTap('DayScreen.initState start');
    super.initState();
    Analytics.trackPageView('/day/${formatDateKey(widget.date)}');

    if (widget.initialPets?.isNotEmpty ?? false) {
      _seedPetsOnly();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PerfLog.markFromTap('DayScreen shell first frame');
        _firstFrameLogged = true;
        if (widget.initialRole != null) {
          _markFullyRendered();
        }
        unawaited(_presentScheduleAsync());
      });
    } else {
      unawaited(_bootstrap());
    }
    PerfLog.markFromTap('DayScreen.initState end');
  }

  void _seedPetsOnly() {
    final initialPets = widget.initialPets!;
    final petId = resolveSelectedPetId(
      initialPets,
      preferredId: widget.initialPetId,
    );
    _pets = initialPets;
    _selectedPetId = petId;
    _plansByPetId = {for (final pet in initialPets) pet.id: null};
    _initialLoading = false;
    _scheduleLoading = true;
  }

  Future<void> _presentScheduleAsync() async {
    return PerfLog.timeFromTap('DayScreen._presentSchedule', () async {
      final generation = ++_loadGeneration;
      final selectedPet = _selectedPet;
      if (selectedPet == null) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() => _scheduleLoading = false);
        return;
      }

      try {
        final scheduleService = ref.read(scheduleServiceProvider);
        final plans = await scheduleService.getPlans();
        final schedule = await scheduleService.getScheduleForPet(
          pet: selectedPet,
          plans: plans,
          referenceDate: widget.date,
        );
        final rows = await scheduleService.getCompletionsForDate(
          householdId: widget.householdId,
          petId: selectedPet.id,
          date: widget.date,
        );
        if (!mounted || generation != _loadGeneration) return;

        setState(() {
          _plans = plans;
          _plan = schedule.plan;
          _tasks = sortTasksChronologically(schedule.tasks);
          _completions = {for (final completion in rows) completion.taskId: completion};
          _plansByPetId = {
            for (final pet in _pets)
              pet.id: resolvePlanForPet(plans, pet, widget.date),
          };
          _scheduleLoading = false;
        });
        PerfLog.markFromTap(
          'DayScreen tasks visible (${schedule.tasks.length} tasks, '
          '${rows.length} done)',
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _loadGeneration) return;
          PerfLog.markFromTap('DayScreen tasks first frame');
          _afterTasksVisible(selectedPet, generation);
        });
      } catch (_) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _scheduleLoading = false;
          _errorMessage = 'Could not load this day. Pull to refresh.';
        });
      }
    });
  }

  void _afterTasksVisible(Pet selectedPet, int generation) {
    unawaited(
      writeSelectedPetId(
        householdId: widget.householdId,
        petId: selectedPet.id,
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || generation != _loadGeneration) return;
      _subscribeToCompletions(selectedPet, generation);
    });
    if (_isToday && !_hasAutoScrolled) {
      _jumpToCurrentTimeEstimate();
    }
    _markFullyRenderedWhenReady(roleLoading: _roleLoading);
  }

  void _markFullyRenderedWhenReady({required bool roleLoading}) {
    if (_fullyRenderedLogged || !_firstFrameLogged) return;
    if (_scheduleLoading || _initialLoading || roleLoading) return;
    _markFullyRendered();
  }

  void _markFullyRendered() {
    if (_fullyRenderedLogged) return;
    _fullyRenderedLogged = true;
    PerfLog.markFromTap(
      'DayScreen fully rendered (builds=$_buildCount, '
      'listItems=$_listItemsBuiltBeforeFirstFrame)',
    );
    _scheduleRasterLog();
  }

  void _scheduleRasterLog() {
    if (_rasterLogged) return;
    final afterMicros = developer.Timeline.now;

    void onTimings(List<FrameTiming> timings) {
      for (final frame in timings) {
        final rasterEnd = frame.timestampInMicroseconds(FramePhase.rasterFinish);
        if (rasterEnd <= afterMicros) continue;

        _rasterLogged = true;
        SchedulerBinding.instance.removeTimingsCallback(onTimings);
        PerfLog.markFromTap(
          'DayScreen rasterized to screen '
          '(build=${frame.buildDuration.inMilliseconds}ms '
          'raster=${frame.rasterDuration.inMilliseconds}ms)',
        );
        return;
      }
    }

    SchedulerBinding.instance.addTimingsCallback(onTimings);
  }

  bool get _isGuest {
    if (widget.initialRole != null) {
      return widget.initialRole == HouseholdRole.guest;
    }
    return ref.watch(householdRoleProvider(widget.householdId)).valueOrNull ==
        HouseholdRole.guest;
  }

  bool get _roleLoading =>
      widget.initialRole == null &&
      ref.watch(householdRoleProvider(widget.householdId)).isLoading;

  void _jumpToCurrentTimeEstimate() {
    if (!_scrollController.hasClients || _tasks.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAutoScrolled) _jumpToCurrentTimeEstimate();
      });
      return;
    }

    final nowIndex = currentTimeInsertIndex(_tasks, DateTime.now());
    const rowHeight = 78.0;
    final rough = ((nowIndex > 0 ? nowIndex - 1 : nowIndex) * rowHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.jumpTo(rough);
    _hasAutoScrolled = true;
  }

  Future<void> _bootstrap() async {
    return PerfLog.time('DayScreen._bootstrap', () async {
      final initialPets = widget.initialPets;
      if (initialPets != null && initialPets.isNotEmpty) {
        _applyPets(initialPets, preferredId: widget.initialPetId);
      } else {
        await _hydrateFromCache();
      }
      if (!mounted) return;
      await _load();
    });
  }

  void _applyPets(List<Pet> pets, {String? preferredId}) {
    final petId = resolveSelectedPetId(pets, preferredId: preferredId);
    setState(() {
      _pets = pets;
      _selectedPetId = petId;
      _initialLoading = false;
      _scheduleLoading = true;
      _plansByPetId = {for (final pet in pets) pet.id: null};
    });
  }

  Future<void> _hydrateFromCache() async {
    final cached = await readLocalCatalogCache();
    if (!mounted || cached == null) return;

    final pets = cached.petsByHousehold[widget.householdId];
    if (pets == null || pets.isEmpty) return;

    final storedPetId = await readSelectedPetId(householdId: widget.householdId);
    _applyPets(
      pets,
      preferredId: widget.initialPetId ?? storedPetId,
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    return PerfLog.time('DayScreen._load', () async {
      final generation = ++_loadGeneration;
      final initialPets = widget.initialPets;
      if (initialPets != null && initialPets.isNotEmpty) {
        await _loadFromCalendar(initialPets, generation: generation);
        return;
      }

      final showInitialLoader = _pets.isEmpty;

      if (showInitialLoader) {
        setState(() {
          _initialLoading = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _scheduleLoading = true;
          _errorMessage = null;
        });
      }

      try {
        final scheduleService = ref.read(scheduleServiceProvider);
        final petsFuture = _pets.isNotEmpty
            ? Future<List<Pet>>.value(_pets)
            : ref.read(petsServiceProvider).getPets(householdId: widget.householdId);

        final results = await Future.wait([
          petsFuture,
          scheduleService.getPlans(),
        ]);
        if (!mounted || generation != _loadGeneration) return;

        final pets = results[0] as List<Pet>;
        final plans = results[1] as List<SchedulePlan>;

        final storedPetId = await readSelectedPetId(householdId: widget.householdId);
        final petId = resolveSelectedPetId(
          pets,
          preferredId: _selectedPetId ?? widget.initialPetId ?? storedPetId,
        );
        if (petId != null) {
          unawaited(
            writeSelectedPetId(
              householdId: widget.householdId,
              petId: petId,
            ),
          );
        }

        final plansByPetId = {
          for (final pet in pets)
            pet.id: resolvePlanForPet(plans, pet, widget.date),
        };

        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _pets = pets;
          _plans = plans;
          _selectedPetId = petId;
          _plansByPetId = plansByPetId;
          _initialLoading = false;
        });

        if (petId != null) {
          await _loadScheduleForPet(petId, generation: generation);
        } else {
          _channel?.unsubscribe();
          _channel = null;
          if (!mounted || generation != _loadGeneration) return;
          setState(() {
            _plan = null;
            _tasks = const [];
            _completions = const {};
            _initialLoading = false;
            _scheduleLoading = false;
          });
        }
      } catch (_) {
        if (!mounted || generation != _loadGeneration) return;
        setState(() {
          _initialLoading = false;
          _scheduleLoading = false;
          _errorMessage = 'Could not load this day. Pull to refresh.';
        });
      }
    });
  }

  Future<void> _loadFromCalendar(
    List<Pet> pets, {
    required int generation,
  }) async {
    return PerfLog.time('DayScreen._loadFromCalendar', () async {
      final petId = resolveSelectedPetId(
        pets,
        preferredId: widget.initialPetId ?? _selectedPetId,
      );
      if (petId == null) {
        setState(() {
          _pets = pets;
          _scheduleLoading = false;
        });
        return;
      }

      final selectedPet = pets.firstWhere((pet) => pet.id == petId);
      final scheduleService = ref.read(scheduleServiceProvider);
      final plans = await scheduleService.getPlans();
      if (!mounted || generation != _loadGeneration) return;

      final schedule = await scheduleService.getScheduleForPet(
        pet: selectedPet,
        plans: plans,
        referenceDate: widget.date,
      );
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _pets = pets;
        _selectedPetId = petId;
        _plans = plans;
        _plansByPetId = {
          for (final pet in pets)
            pet.id: resolvePlanForPet(plans, pet, widget.date),
        };
        _plan = schedule.plan;
        _tasks = sortTasksChronologically(schedule.tasks);
        _completions = const {};
        _initialLoading = false;
        _scheduleLoading = false;
      });
      PerfLog.markFromTap('DayScreen tasks visible (${schedule.tasks.length} tasks)');

      unawaited(
        writeSelectedPetId(
          householdId: widget.householdId,
          petId: petId,
        ),
      );
      unawaited(_syncCompletions(selectedPet, generation));

      if (_isToday && !_hasAutoScrolled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasAutoScrolled) _scrollToCurrentTime();
        });
      }
    });
  }

  Future<void> _loadScheduleForPet(String petId, {int? generation}) async {
    return PerfLog.time('DayScreen._loadScheduleForPet($petId)', () async {
      final loadGeneration = generation ?? ++_loadGeneration;
      final selectedPet = _pets.where((pet) => pet.id == petId).firstOrNull;
      if (selectedPet == null) return;

      if (generation == null) {
        setState(() {
          _selectedPetId = petId;
          _hasAutoScrolled = false;
        });
      }

      setState(() {
        _scheduleLoading = true;
        _errorMessage = null;
      });

      try {
        final scheduleService = ref.read(scheduleServiceProvider);
        final schedule = await scheduleService.getScheduleForPet(
          pet: selectedPet,
          plans: _plans,
          referenceDate: widget.date,
        );
        if (!mounted || loadGeneration != _loadGeneration) return;
        setState(() {
          _selectedPetId = petId;
          _plan = schedule.plan;
          _tasks = sortTasksChronologically(schedule.tasks);
          _completions = const {};
          _scheduleLoading = false;
        });
        PerfLog.markFromTap('DayScreen tasks visible (${schedule.tasks.length} tasks)');

        if (_isToday && !_hasAutoScrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_hasAutoScrolled) _scrollToCurrentTime();
          });
        }

        unawaited(_syncCompletions(selectedPet, loadGeneration));
      } catch (_) {
        if (!mounted || loadGeneration != _loadGeneration) return;
        setState(() {
          _initialLoading = false;
          _scheduleLoading = false;
          _errorMessage = 'Could not load this schedule. Pull to refresh.';
        });
      }
    });
  }

  Future<void> _syncCompletions(Pet selectedPet, int loadGeneration) async {
    return PerfLog.time('DayScreen._syncCompletions', () async {
      try {
        final scheduleService = ref.read(scheduleServiceProvider);
        final rows = await scheduleService.getCompletionsForDate(
          householdId: widget.householdId,
          petId: selectedPet.id,
          date: widget.date,
        );
        if (!mounted || loadGeneration != _loadGeneration) return;

        setState(() {
          _completions = {for (final completion in rows) completion.taskId: completion};
        });
        PerfLog.markFromTap('DayScreen completions visible (${rows.length} done)');

        _subscribeToCompletions(selectedPet, loadGeneration);
      } catch (_) {
        // Tasks stay visible even if completion sync fails.
      }
    });
  }

  void _subscribeToCompletions(Pet selectedPet, int loadGeneration) {
    if (!mounted || loadGeneration != _loadGeneration) return;

    final scheduleService = ref.read(scheduleServiceProvider);
    _channel?.unsubscribe();
    _channel = scheduleService.subscribeToCompletions(
      householdId: widget.householdId,
      petId: selectedPet.id,
      date: widget.date,
      onChange: () => _refreshCompletions(),
    );
    PerfLog.markFromTap('DayScreen subscribed to completion updates');
  }

  Future<void> _selectPet(String petId) async {
    if (_selectedPetId == petId || _scheduleLoading) return;
    await writeSelectedPetId(householdId: widget.householdId, petId: petId);
    if (!mounted) return;
    await _loadScheduleForPet(petId);
  }

  Future<void> _refreshCompletions() async {
    final selectedPet = _selectedPet;
    if (!mounted || selectedPet == null) return;

    final scheduleService = ref.read(scheduleServiceProvider);
    scheduleService.invalidateCompletionsCache(
      householdId: widget.householdId,
      petId: selectedPet.id,
      date: widget.date,
    );
    final completions = await scheduleService.getCompletionsForDate(
          householdId: widget.householdId,
          petId: selectedPet.id,
          date: widget.date,
        );
    if (mounted) {
      setState(() {
        _completions = {for (final completion in completions) completion.taskId: completion};
      });
    }
  }

  Future<void> _toggleTask(ScheduleTask task, bool completed) async {
    final selectedPet = _selectedPet;
    final userId = ref.read(authServiceProvider).currentUserId;
    if (selectedPet == null || userId == null) return;

    setState(() => _loadingTasks.add(task.id));
    try {
      final service = ref.read(scheduleServiceProvider);
      if (completed) {
        await service.completeTask(
          householdId: widget.householdId,
          petId: selectedPet.id,
          taskId: task.id,
          date: widget.date,
          userId: userId,
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
          householdId: widget.householdId,
          petId: selectedPet.id,
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

    final selectedPet = _selectedPet;
    final userId = ref.read(authServiceProvider).currentUserId;
    if (selectedPet == null || userId == null) return;

    final incompleteTaskIds = _tasks
        .where((task) => !_completions.containsKey(task.id))
        .map((task) => task.id)
        .toList();
    if (incompleteTaskIds.isEmpty) return;

    setState(() => _markingAll = true);
    try {
      await ref.read(scheduleServiceProvider).completeAllTasks(
            householdId: widget.householdId,
            petId: selectedPet.id,
            taskIds: incompleteTaskIds,
            date: widget.date,
            userId: userId,
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
    ref.listen<int>(scheduleRevisionProvider, (previous, next) {
      if (previous == null || previous == next) return;
      final petId = _selectedPetId;
      if (petId == null || _initialLoading) return;
      ref.read(scheduleServiceProvider).invalidateScheduleCache(petId: petId);
      unawaited(_loadScheduleForPet(petId));
    });

    final buildStart = Stopwatch()..start();
    _buildCount++;
    final buildNum = _buildCount;

    final dateLabel = DateFormat.yMMMMEEEEd().format(widget.date);
    final completedCount =
        _tasks.where((task) => _completions.containsKey(task.id)).length;
    final totalCount = _tasks.length;
    final allCompleted = totalCount > 0 && completedCount >= totalCount;
    final isGuest = _isGuest;
    final accent = _theme.progressAccent;

    if (buildNum <= 3) {
      PerfLog.markFromTap(
        'DayScreen.build #$buildNum start '
        '(tasks=$totalCount loading=$_scheduleLoading '
        'role=${_roleLoading ? "loading" : widget.initialRole ?? ref.read(householdRoleProvider(widget.householdId)).valueOrNull})',
      );
    }

    final body = Theme(
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
        body: _initialLoading && _pets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: PetSelector(
                      pets: _pets,
                      selectedPetId: _selectedPetId,
                      plansByPetId: _plansByPetId,
                      theme: _theme,
                      onSelect: _selectPet,
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _theme.textSecondary, height: 1.5),
                      ),
                    ),
                  if (_pets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Add a pet in Settings to see an age-appropriate schedule.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _theme.textSecondary, height: 1.5),
                      ),
                    ),
                  if (_tasks.isNotEmpty && !_scheduleLoading)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _ProgressBanner(
                        completed: completedCount,
                        total: totalCount,
                        theme: _theme,
                      ),
                    ),
                  Expanded(
                    child: _scheduleLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: _theme.progressAccent,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: _buildTaskScrollView(
                              accent: accent,
                              isGuest: isGuest,
                              allCompleted: allCompleted,
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );

    if (buildNum <= 3) {
      PerfLog.markFromTap(
        'DayScreen.build #$buildNum done (${buildStart.elapsedMilliseconds}ms sync)',
      );
    }
    _markFullyRenderedWhenReady(roleLoading: _roleLoading);
    return body;
  }

  Widget _buildTaskScrollView({
    required Color accent,
    required bool isGuest,
    required bool allCompleted,
  }) {
    return PerfLog.timeSyncFromTap('DayScreen._buildTaskScrollView', () {
      final selectedPet = _selectedPet;
      final entries = buildDayListEntries(tasks: _tasks, isToday: _isToday);
      final hasTips = _plan?.tipsBody != null;
      final hasMarkAll = _tasks.isNotEmpty && !isGuest;

      if (_buildCount <= 3) {
        PerfLog.markFromTap(
          'DayScreen scrollView ${entries.length} entries '
          '(tasks=${_tasks.length} tips=$hasTips markAll=$hasMarkAll)',
        );
      }

      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        cacheExtent: 0,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (selectedPet == null) return const SizedBox.shrink();
                  if (!_firstFrameLogged) {
                    _listItemsBuiltBeforeFirstFrame++;
                    if (_listItemsBuiltBeforeFirstFrame <= 10) {
                      PerfLog.markFromTap(
                        'DayScreen listItem[$index] ${entries[index].kind.name}',
                      );
                    } else if (_listItemsBuiltBeforeFirstFrame == 11) {
                      PerfLog.markFromTap('DayScreen listItem[…] (further items omitted)');
                    }
                    if (index == entries.length - 1) {
                      PerfLog.markFromTap(
                        'DayScreen last listItem built '
                        '($index ${entries[index].kind.name}, '
                        'total=${entries.length})',
                      );
                    }
                  }
                  return _buildListEntry(entries[index], accent, selectedPet);
                },
                childCount: entries.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
        if (hasTips)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(child: _TipBox(plan: _plan!, theme: _theme)),
          ),
        if (hasMarkAll)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: allCompleted || _markingAll ? null : _markAllCompleted,
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
                          style: AppFonts.nunito(
                            fontWeight: FontWeight.w700,
                            fontSize: AppFonts.sz(15),
                          ),
                        ),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
    });
  }

  Widget _buildListEntry(DayListEntry entry, Color accent, Pet selectedPet) {
    switch (entry.kind) {
      case DayListEntryKind.section:
        return SectionDivider(label: entry.sectionLabel!, color: _theme.divider);
      case DayListEntryKind.nowLine:
        return _CurrentTimeLine(
          key: _nowLineKey,
          time: entry.now!,
          accent: accent,
        );
      case DayListEntryKind.task:
        final task = entry.task!;
        return ScheduleBlock(
          key: entry.isScrollAnchor
              ? _scrollAnchorKey
              : entry.isCurrentSlot
                  ? _currentSlotKey
                  : null,
          task: task,
          species: selectedPet.species,
          theme: _theme,
          completion: _completions[task.id],
          loading: _loadingTasks.contains(task.id),
          onToggle: (value) => _toggleTask(task, value),
        );
    }
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
            style: AppFonts.nunito(
              fontSize: AppFonts.sz(11),
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
                style: AppFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: AppFonts.sz(15),
                  color: theme.textPrimary,
                ),
              ),
              Text(
                '$completed / $total',
                style: AppFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: AppFonts.sz(15),
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
          EmojiAwareText(
            plan.tipsTitle ?? 'Key Notes',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: AppFonts.sz(13),
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          EmojiAwareText(
            plan.tipsBody!,
            style: TextStyle(
              fontSize: AppFonts.sz(12.5),
              height: 1.6,
              color: theme.tipText,
            ),
          ),
        ],
      ),
    );
  }
}
