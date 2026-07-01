import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completion.dart';
import '../models/pet.dart';
import '../models/pet_schedule_meta.dart';
import '../models/schedule_plan.dart';
import '../models/schedule_task.dart';
import '../utils/perf_log.dart';
import '../utils/schedule_plan.dart';
import '../utils/schedule_task_id.dart';

class ScheduleService {
  ScheduleService(this._client);

  final SupabaseClient? _client;
  List<SchedulePlan>? _plansCache;
  Future<List<SchedulePlan>>? _plansInflight;
  final Map<String, List<ScheduleTask>> _tasksByPlanId = {};
  final Map<String, Future<List<ScheduleTask>>> _tasksInflightByPlanId = {};
  final Map<String, PetScheduleMeta?> _metaByPetId = {};
  final Map<String, Future<PetScheduleMeta?>> _metaInflightByPetId = {};
  final Map<String, List<ScheduleTask>> _customTasksByPetId = {};
  final Map<String, Future<List<ScheduleTask>>> _customTasksInflightByPetId = {};
  final Map<String, List<Completion>> _completionsByKey = {};
  final Map<String, Future<List<Completion>>> _completionsInflightByKey = {};
  final Map<String, int> _metaGeneration = {};
  final Map<String, int> _customTasksGeneration = {};

  /// Clears in-memory schedule caches. Pass [petId] when only one pet's schedule changed.
  void invalidateScheduleCache({String? petId}) {
    if (petId == null) {
      _plansCache = null;
      _tasksByPlanId.clear();
      _metaByPetId.clear();
      _customTasksByPetId.clear();
      _completionsByKey.clear();
      _metaInflightByPetId.clear();
      _customTasksInflightByPetId.clear();
      _metaGeneration.clear();
      _customTasksGeneration.clear();
      return;
    }
    _metaGeneration[petId] = (_metaGeneration[petId] ?? 0) + 1;
    _customTasksGeneration[petId] = (_customTasksGeneration[petId] ?? 0) + 1;
    _metaByPetId.remove(petId);
    _customTasksByPetId.remove(petId);
    _metaInflightByPetId.remove(petId);
    _customTasksInflightByPetId.remove(petId);
  }

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<SchedulePlan>> getPlans() async {
    if (_plansCache != null) {
      PerfLog.mark('ScheduleService.getPlans cache hit');
      return _plansCache!;
    }
    if (_plansInflight != null) {
      PerfLog.mark('ScheduleService.getPlans awaiting inflight');
      return _plansInflight!;
    }

    _plansInflight = PerfLog.time('ScheduleService.getPlans', _fetchPlans);
    try {
      return await _plansInflight!;
    } finally {
      _plansInflight = null;
    }
  }

  Future<List<SchedulePlan>> _fetchPlans() async {
    final data = await _requiredClient
        .from('schedule_plans')
        .select()
        .order('species')
        .order('min_age_days');

    return _plansCache = (data as List)
        .map((row) => SchedulePlan.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ScheduleTask>> getTasksForPlan(String planId) async {
    if (planId.trim().isEmpty) return [];
    final cached = _tasksByPlanId[planId];
    if (cached != null) {
      PerfLog.mark('ScheduleService.getTasksForPlan($planId) cache hit');
      return cached;
    }

    final inflight = _tasksInflightByPlanId[planId];
    if (inflight != null) {
      PerfLog.mark('ScheduleService.getTasksForPlan($planId) awaiting inflight');
      return inflight;
    }

    final future = PerfLog.time(
      'ScheduleService.getTasksForPlan($planId)',
      () => _fetchTasksForPlan(planId),
    );
    _tasksInflightByPlanId[planId] = future;
    try {
      return await future;
    } finally {
      _tasksInflightByPlanId.remove(planId);
    }
  }

  Future<List<ScheduleTask>> _fetchTasksForPlan(String planId) async {
    final data = await _requiredClient
        .from('schedule_tasks')
        .select()
        .eq('plan_id', planId)
        .order('sort_order', ascending: true);

    return _tasksByPlanId[planId] = (data as List)
        .map((row) => ScheduleTask.fromJson(row as Map<String, dynamic>))
        .where((task) => task.planId == planId)
        .toList();
  }

  Future<PetScheduleMeta?> getPetScheduleMeta(String petId) async {
    if (_metaByPetId.containsKey(petId)) {
      PerfLog.mark('ScheduleService.getPetScheduleMeta($petId) cache hit');
      return _metaByPetId[petId];
    }

    final inflight = _metaInflightByPetId[petId];
    if (inflight != null) {
      PerfLog.mark('ScheduleService.getPetScheduleMeta($petId) awaiting inflight');
      return inflight;
    }

    final generation = _metaGeneration[petId] ?? 0;
    final future = PerfLog.time(
      'ScheduleService.getPetScheduleMeta($petId)',
      () => _fetchPetScheduleMeta(petId, generation),
    );
    _metaInflightByPetId[petId] = future;
    try {
      return await future;
    } finally {
      _metaInflightByPetId.remove(petId);
    }
  }

  Future<PetScheduleMeta?> _fetchPetScheduleMeta(String petId, int generation) async {
    final data = await _requiredClient
        .from('pet_schedules')
        .select()
        .eq('pet_id', petId)
        .maybeSingle();
    final meta = data == null ? null : PetScheduleMeta.fromJson(data);
    if ((_metaGeneration[petId] ?? 0) == generation) {
      _metaByPetId[petId] = meta;
    }
    return meta;
  }

  Future<List<ScheduleTask>> getCustomTasksForPet(String petId) async {
    final cached = _customTasksByPetId[petId];
    if (cached != null) return cached;

    final inflight = _customTasksInflightByPetId[petId];
    if (inflight != null) return inflight;

    final generation = _customTasksGeneration[petId] ?? 0;
    final future = _fetchCustomTasksForPet(petId, generation);
    _customTasksInflightByPetId[petId] = future;
    try {
      return await future;
    } finally {
      _customTasksInflightByPetId.remove(petId);
    }
  }

  Future<List<ScheduleTask>> _fetchCustomTasksForPet(
    String petId,
    int generation,
  ) async {
    final data = await _requiredClient
        .from('pet_schedule_tasks')
        .select()
        .eq('pet_id', petId)
        .order('sort_order', ascending: true);
    final tasks = (data as List)
        .map((row) => ScheduleTask.fromJson(row as Map<String, dynamic>))
        .toList();
    if ((_customTasksGeneration[petId] ?? 0) == generation) {
      _customTasksByPetId[petId] = tasks;
    }
    return tasks;
  }

  Future<void> _repairBrokenCustomSchedule(String petId) async {
    await _requiredClient.from('pet_schedules').delete().eq('pet_id', petId);
    invalidateScheduleCache(petId: petId);
  }

  /// Saved custom tasks, or null when the pet should use its default plan.
  /// Clears a customized flag left behind by a failed save with no tasks.
  Future<List<ScheduleTask>?> getValidCustomTasksForPet(String petId) async {
    final meta = await getPetScheduleMeta(petId);
    final tasks = await getCustomTasksForPet(petId);

    if (meta?.isCustomized == true) {
      if (tasks.isNotEmpty) return tasks;
      await _repairBrokenCustomSchedule(petId);
      return null;
    }

    if (tasks.isNotEmpty) return tasks;

    return null;
  }

  Future<({SchedulePlan? plan, List<ScheduleTask> tasks})> getScheduleForPet({
    required Pet pet,
    required List<SchedulePlan> plans,
    DateTime? referenceDate,
  }) {
    return PerfLog.time(
      'ScheduleService.getScheduleForPet(${pet.name})',
      () async {
        final plan = resolvePlanForPet(plans, pet, referenceDate);
        final customTasks = await getValidCustomTasksForPet(pet.id);
        if (customTasks != null) {
          return (plan: plan, tasks: customTasks);
        }

        if (plan == null) {
          return (plan: null, tasks: <ScheduleTask>[]);
        }

        final tasks = await getTasksForPlan(plan.id);
        return (plan: plan, tasks: tasks);
      },
    );
  }

  void invalidateCompletionsCache({
    required String householdId,
    required String petId,
    required DateTime date,
  }) {
    _completionsByKey.remove(_completionsKey(householdId, petId, date));
    _completionsInflightByKey.remove(_completionsKey(householdId, petId, date));
  }

  String _completionsKey(String householdId, String petId, DateTime date) {
    return '$householdId:$petId:${_formatDate(date)}';
  }

  Future<List<Completion>> getCompletionsForDate({
    required String householdId,
    required String petId,
    required DateTime date,
  }) {
    final key = _completionsKey(householdId, petId, date);
    final cached = _completionsByKey[key];
    if (cached != null) {
      PerfLog.mark('ScheduleService.getCompletionsForDate($petId) cache hit');
      return Future.value(cached);
    }

    final inflight = _completionsInflightByKey[key];
    if (inflight != null) {
      PerfLog.mark('ScheduleService.getCompletionsForDate($petId) awaiting inflight');
      return inflight;
    }

    final future = PerfLog.time(
      'ScheduleService.getCompletionsForDate($petId)',
      () => _fetchCompletionsForDate(
        householdId: householdId,
        petId: petId,
        date: date,
      ),
    );
    _completionsInflightByKey[key] = future;
    return future.whenComplete(() => _completionsInflightByKey.remove(key));
  }

  Future<List<Completion>> _fetchCompletionsForDate({
    required String householdId,
    required String petId,
    required DateTime date,
  }) async {
    final key = _completionsKey(householdId, petId, date);
    final dateStr = _formatDate(date);
    final data = await _requiredClient
        .from('completions')
        .select('*, profiles!completed_by(display_name)')
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .eq('date', dateStr);

    return _completionsByKey[key] = (data as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);
      final profile = map.remove('profiles') as Map<String, dynamic>?;
      return Completion.fromJson({
        ...map,
        'completed_by_name': profile?['display_name'],
      });
    }).toList();
  }

  Future<Map<DateTime, int>> getCompletionCountsForMonth({
    required String householdId,
    required String petId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final data = await _requiredClient
        .from('completions')
        .select('date')
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .gte('date', _formatDate(start))
        .lte('date', _formatDate(end));

    final counts = <DateTime, int>{};
    for (final row in data as List) {
      final date = DateTime.parse(row['date'] as String);
      final key = DateTime(date.year, date.month, date.day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  Future<Map<DateTime, int>> getHouseholdCompletionsForMonth({
    required String householdId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final data = await _requiredClient
        .from('completions')
        .select('date')
        .eq('household_id', householdId)
        .gte('date', _formatDate(start))
        .lte('date', _formatDate(end));

    final completionCounts = <DateTime, int>{};
    for (final row in data as List) {
      final date = DateTime.parse(row['date'] as String);
      final key = DateTime(date.year, date.month, date.day);
      completionCounts[key] = (completionCounts[key] ?? 0) + 1;
    }
    return completionCounts;
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      days.add(DateTime(cursor.year, cursor.month, cursor.day));
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  Future<Map<DateTime, int>> getDayTotalsForPet({
    required Pet pet,
    required List<SchedulePlan> plans,
    required DateTime month,
  }) async {
    final days = _daysInMonth(month);

    final customTasks = await getValidCustomTasksForPet(pet.id);
    if (customTasks != null) {
      return {for (final day in days) day: customTasks.length};
    }

    final tasksByPlanId = <String, Future<List<ScheduleTask>>>{};
    Future<List<ScheduleTask>> loadTasksForPlan(String planId) {
      return tasksByPlanId.putIfAbsent(planId, () => getTasksForPlan(planId));
    }

    final totals = <DateTime, int>{};
    for (final day in days) {
      final plan = resolvePlanForPet(plans, pet, day);
      if (plan == null) {
        totals[day] = 0;
      } else {
        totals[day] = (await loadTasksForPlan(plan.id)).length;
      }
    }
    return totals;
  }

  Future<({Map<DateTime, int> completions, Map<DateTime, int> totals})>
      getAggregatedCountsForMonth({
    required String householdId,
    required List<Pet> pets,
    required List<SchedulePlan> plans,
    required DateTime month,
  }) {
    return PerfLog.time(
      'ScheduleService.getAggregatedCountsForMonth(${pets.length} pets)',
      () async {
        final completions = await getHouseholdCompletionsForMonth(
          householdId: householdId,
          month: month,
        );

        final totals = <DateTime, int>{};
        for (final pet in pets) {
          final petTotals = await getDayTotalsForPet(
            pet: pet,
            plans: plans,
            month: month,
          );
          petTotals.forEach((day, count) {
            totals[day] = (totals[day] ?? 0) + count;
          });
        }

        return (completions: completions, totals: totals);
      },
    );
  }

  Future<void> completeTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
    required String userId,
  }) async {
    await _requiredClient.from('completions').upsert(
      {
        'household_id': householdId,
        'pet_id': petId,
        'task_id': taskId,
        'date': _formatDate(date),
        'completed_by': userId,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'pet_id,task_id,date',
    );
    invalidateCompletionsCache(householdId: householdId, petId: petId, date: date);
  }

  Future<void> completeAllTasks({
    required String householdId,
    required String petId,
    required List<String> taskIds,
    required DateTime date,
    required String userId,
  }) async {
    if (taskIds.isEmpty) return;

    final completedAt = DateTime.now().toUtc().toIso8601String();
    final dateStr = _formatDate(date);
    await _requiredClient.from('completions').upsert(
      [
        for (final taskId in taskIds)
          {
            'household_id': householdId,
            'pet_id': petId,
            'task_id': taskId,
            'date': dateStr,
            'completed_by': userId,
            'completed_at': completedAt,
          },
      ],
      onConflict: 'pet_id,task_id,date',
    );
    invalidateCompletionsCache(householdId: householdId, petId: petId, date: date);
  }

  Future<void> uncompleteTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
  }) async {
    await _requiredClient
        .from('completions')
        .delete()
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .eq('task_id', taskId)
        .eq('date', _formatDate(date));
    invalidateCompletionsCache(householdId: householdId, petId: petId, date: date);
  }

  Future<void> saveCustomSchedule({
    required String petId,
    required String? basePlanId,
    required List<ScheduleTask> tasks,
    required String userId,
  }) async {
    final taskPayload = [
      for (var i = 0; i < tasks.length; i++)
        {
          if (isPersistedCustomTaskId(tasks[i].id)) 'id': tasks[i].id,
          'sort_order': i,
          'time_label': tasks[i].timeLabel,
          'category': tasks[i].category,
          'title': tasks[i].title,
          'subtitle': tasks[i].subtitle ?? '',
          'icon': tasks[i].icon,
          'section': tasks[i].section,
        },
    ];

    try {
      await _requiredClient.rpc('save_pet_custom_schedule', params: {
        'p_pet_id': petId,
        'p_base_plan_id': basePlanId,
        'p_tasks': taskPayload,
      });
      invalidateScheduleCache(petId: petId);
      return;
    } on PostgrestException catch (e) {
      final rpcMissing = e.code == 'PGRST202' ||
          (e.message.contains('save_pet_custom_schedule'));
      if (!rpcMissing) rethrow;
    }

    await _requiredClient.from('pet_schedules').upsert({
      'pet_id': petId,
      'base_plan_id': basePlanId,
      'is_customized': true,
      'customized_at': DateTime.now().toUtc().toIso8601String(),
      'customized_by': userId,
    }, onConflict: 'pet_id');

    await _requiredClient.from('pet_schedule_tasks').delete().eq('pet_id', petId);
    if (tasks.isNotEmpty) {
      await _requiredClient.from('pet_schedule_tasks').insert([
        for (var i = 0; i < tasks.length; i++)
          {
            if (isPersistedCustomTaskId(tasks[i].id)) 'id': tasks[i].id,
            'pet_id': petId,
            'sort_order': i,
            'time_label': tasks[i].timeLabel,
            'category': tasks[i].category,
            'title': tasks[i].title,
            'subtitle': tasks[i].subtitle,
            'icon': tasks[i].icon,
            'section': tasks[i].section,
          },
      ]);
    }

    invalidateScheduleCache(petId: petId);
  }

  Future<void> resetScheduleToDefault(String petId) async {
    await _requiredClient.from('pet_schedule_tasks').delete().eq('pet_id', petId);
    await _requiredClient.from('pet_schedules').delete().eq('pet_id', petId);
    invalidateScheduleCache(petId: petId);
  }

  Future<({SchedulePlan? plan, List<ScheduleTask> tasks})> copyPlanToCustomDraft({
    required Pet pet,
    required List<SchedulePlan> plans,
    required DateTime referenceDate,
  }) async {
    final plan = resolvePlanForPet(plans, pet, referenceDate);
    if (plan == null) return (plan: null, tasks: const <ScheduleTask>[]);
    final baseTasks = await getTasksForPlan(plan.id);
    final draftTasks = baseTasks
        .map(
          (task) => ScheduleTask(
            id: 'new-${DateTime.now().microsecondsSinceEpoch}-${task.id}',
            planId: null,
            petId: pet.id,
            sortOrder: task.sortOrder,
            timeLabel: task.timeLabel,
            category: task.category,
            title: task.title,
            subtitle: task.subtitle,
            icon: task.icon,
            section: task.section,
            isCustom: true,
          ),
        )
        .toList();
    return (plan: plan, tasks: draftTasks);
  }

  RealtimeChannel? subscribeToCompletions({
    required String householdId,
    required String petId,
    required DateTime date,
    required void Function() onChange,
  }) {
    final channel = _requiredClient.channel('completions-$petId-${_formatDate(date)}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'completions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: householdId,
      ),
      callback: (_) => onChange(),
    );
    channel.subscribe();
    return channel;
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
