import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_mode.dart';
import '../demo/roadmap_demo_store.dart';
import '../models/completion.dart';
import '../models/pet.dart';
import '../models/pet_schedule_meta.dart';
import '../models/schedule_plan.dart';
import '../models/schedule_task.dart';
import '../utils/schedule_plan.dart';

class ScheduleService {
  ScheduleService(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    return client;
  }

  Future<List<SchedulePlan>> getPlans() async {
    if (isRoadmapDemo) {
      try {
        final data = await _requiredClient
            .from('schedule_plans')
            .select()
            .order('species')
            .order('min_age_days');
        if ((data as List).isNotEmpty) {
          return data
              .map((row) => SchedulePlan.fromJson(row))
              .toList();
        }
      } catch (_) {
        // fall through to seed data
      }
      return RoadmapDemoStore.instance.getPlans();
    }

    final data = await _requiredClient
        .from('schedule_plans')
        .select()
        .order('species')
        .order('min_age_days');

    return (data as List)
        .map((row) => SchedulePlan.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ScheduleTask>> getTasksForPlan(String planId) async {
    if (planId.trim().isEmpty) return [];
    if (isRoadmapDemo) {
      try {
        final data = await _requiredClient
            .from('schedule_tasks')
            .select()
            .eq('plan_id', planId)
            .order('sort_order', ascending: true);
        if ((data as List).isNotEmpty) {
          return data
              .map((row) => ScheduleTask.fromJson(row))
              .where((task) => task.planId == planId)
              .toList();
        }
      } catch (_) {
        // fall through to seed data
      }
      return RoadmapDemoStore.instance.getTasksForPlan(planId);
    }

    final data = await _requiredClient
        .from('schedule_tasks')
        .select()
        .eq('plan_id', planId)
        .order('sort_order', ascending: true);

    return (data as List)
        .map((row) => ScheduleTask.fromJson(row as Map<String, dynamic>))
        .where((task) => task.planId == planId)
        .toList();
  }

  Future<PetScheduleMeta?> getPetScheduleMeta(String petId) async {
    if (isRoadmapDemo) return RoadmapDemoStore.instance.getPetScheduleMeta(petId);
    final data = await _requiredClient
        .from('pet_schedules')
        .select()
        .eq('pet_id', petId)
        .maybeSingle();
    if (data == null) return null;
    return PetScheduleMeta.fromJson(data);
  }

  Future<List<ScheduleTask>> getCustomTasksForPet(String petId) async {
    if (isRoadmapDemo) return RoadmapDemoStore.instance.getCustomTasksForPet(petId);
    final data = await _requiredClient
        .from('pet_schedule_tasks')
        .select()
        .eq('pet_id', petId)
        .order('sort_order', ascending: true);
    return (data as List)
        .map((row) => ScheduleTask.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<({SchedulePlan? plan, List<ScheduleTask> tasks})> getScheduleForPet({
    required Pet pet,
    required List<SchedulePlan> plans,
    DateTime? referenceDate,
  }) async {
    final plan = resolvePlanForPet(plans, pet, referenceDate);
    if (isRoadmapDemo) {
      return RoadmapDemoStore.instance
          .getScheduleForPet(pet, referenceDate ?? DateTime.now());
    }

    final meta = await getPetScheduleMeta(pet.id);
    if (meta?.isCustomized == true) {
      final customTasks = await getCustomTasksForPet(pet.id);
      return (plan: plan, tasks: customTasks);
    }

    if (plan == null) {
      return (plan: null, tasks: <ScheduleTask>[]);
    }

    final tasks = await getTasksForPlan(plan.id);
    return (plan: plan, tasks: tasks);
  }

  Future<List<Completion>> getCompletionsForDate({
    required String householdId,
    required String petId,
    required DateTime date,
  }) async {
    if (isRoadmapDemo) {
      return RoadmapDemoStore.instance
          .getCompletionsForDate(householdId, petId, date);
    }
    final dateStr = _formatDate(date);
    final data = await _requiredClient
        .from('completions')
        .select('*, profiles!completed_by(display_name)')
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .eq('date', dateStr);

    return (data as List).map((row) {
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
    if (isRoadmapDemo) {
      final pets = RoadmapDemoStore.instance.getPets(householdId);
      final selectedPet = pets.where((pet) => pet.id == petId).toList();
      final aggregated = RoadmapDemoStore.instance
          .getAggregatedCountsForMonth(householdId, selectedPet, month);
      final counts = <DateTime, int>{};
      aggregated.completions.forEach((key, value) {
        final date = DateTime.parse('${key}T00:00:00');
        counts[DateTime(date.year, date.month, date.day)] = value;
      });
      return counts;
    }

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

  Future<({Map<DateTime, int> completions, Map<DateTime, int> totals})>
      getAggregatedCountsForMonth({
    required String householdId,
    required List<Pet> pets,
    required List<SchedulePlan> plans,
    required DateTime month,
  }) async {
    if (isRoadmapDemo) {
      final response = RoadmapDemoStore.instance
          .getAggregatedCountsForMonth(householdId, pets, month);
      final completions = <DateTime, int>{};
      final totals = <DateTime, int>{};
      response.completions.forEach((key, value) {
        final date = DateTime.parse('${key}T00:00:00');
        completions[DateTime(date.year, date.month, date.day)] = value;
      });
      response.totals.forEach((key, value) {
        final date = DateTime.parse('${key}T00:00:00');
        totals[DateTime(date.year, date.month, date.day)] = value;
      });
      return (completions: completions, totals: totals);
    }

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

    final totals = <DateTime, int>{};
    var cursor = start;
    while (!cursor.isAfter(end)) {
      var total = 0;
      for (final pet in pets) {
        total +=
            (await getScheduleForPet(pet: pet, plans: plans, referenceDate: cursor))
                .tasks
                .length;
      }
      totals[DateTime(cursor.year, cursor.month, cursor.day)] = total;
      cursor = cursor.add(const Duration(days: 1));
    }

    return (completions: completionCounts, totals: totals);
  }

  Future<void> completeTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
    required String userId,
  }) async {
    if (isRoadmapDemo) {
      RoadmapDemoStore.instance.completeTask(
        householdId,
        petId,
        taskId,
        date,
        userId,
      );
      return;
    }
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
  }

  Future<void> completeAllTasks({
    required String householdId,
    required String petId,
    required List<String> taskIds,
    required DateTime date,
    required String userId,
  }) async {
    if (isRoadmapDemo) {
      RoadmapDemoStore.instance
          .completeAllTasks(householdId, petId, taskIds, date, userId);
      return;
    }
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
  }

  Future<void> uncompleteTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
  }) async {
    if (isRoadmapDemo) {
      RoadmapDemoStore.instance.uncompleteTask(householdId, petId, taskId, date);
      return;
    }
    await _requiredClient
        .from('completions')
        .delete()
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .eq('task_id', taskId)
        .eq('date', _formatDate(date));
  }

  Future<void> saveCustomSchedule({
    required String petId,
    required String? basePlanId,
    required List<ScheduleTask> tasks,
    required String userId,
  }) async {
    if (isRoadmapDemo) {
      RoadmapDemoStore.instance.saveCustomSchedule(petId, basePlanId, tasks, userId);
      return;
    }
    await _requiredClient.from('pet_schedule_tasks').delete().eq('pet_id', petId);
    if (tasks.isNotEmpty) {
      await _requiredClient.from('pet_schedule_tasks').insert([
        for (var i = 0; i < tasks.length; i++)
          {
            'id': tasks[i].id.startsWith('new-') ? null : tasks[i].id,
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
    await _requiredClient.from('pet_schedules').upsert({
      'pet_id': petId,
      'base_plan_id': basePlanId,
      'is_customized': true,
      'customized_at': DateTime.now().toUtc().toIso8601String(),
      'customized_by': userId,
    }, onConflict: 'pet_id');
  }

  Future<void> resetScheduleToDefault(String petId) async {
    if (isRoadmapDemo) {
      RoadmapDemoStore.instance.resetScheduleToDefault(petId);
      return;
    }
    await _requiredClient.from('pet_schedule_tasks').delete().eq('pet_id', petId);
    await _requiredClient.from('pet_schedules').delete().eq('pet_id', petId);
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
    if (isRoadmapDemo) return null;
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
