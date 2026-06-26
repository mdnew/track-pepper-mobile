import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/completion.dart';
import '../models/schedule_plan.dart';
import '../models/schedule_task.dart';

class ScheduleService {
  ScheduleService(this._client);

  final SupabaseClient _client;

  Future<List<SchedulePlan>> getPlans() async {
    final data = await _client
        .from('schedule_plans')
        .select()
        .order('species')
        .order('min_age_days');

    return (data as List)
        .map((row) => SchedulePlan.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<ScheduleTask>> getTasksForPlan(String planId) async {
    final data = await _client
        .from('schedule_tasks')
        .select()
        .eq('plan_id', planId)
        .order('sort_order', ascending: true);

    return (data as List)
        .map((row) => ScheduleTask.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<Completion>> getCompletionsForDate({
    required String householdId,
    required String petId,
    required DateTime date,
  }) async {
    final dateStr = _formatDate(date);
    final data = await _client
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
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final data = await _client
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

  Future<void> completeTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
    required String userId,
  }) async {
    await _client.from('completions').upsert(
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

  Future<void> uncompleteTask({
    required String householdId,
    required String petId,
    required String taskId,
    required DateTime date,
  }) async {
    await _client
        .from('completions')
        .delete()
        .eq('household_id', householdId)
        .eq('pet_id', petId)
        .eq('task_id', taskId)
        .eq('date', _formatDate(date));
  }

  RealtimeChannel subscribeToCompletions({
    required String householdId,
    required String petId,
    required DateTime date,
    required void Function() onChange,
  }) {
    final channel = _client.channel('completions-$petId-${_formatDate(date)}');
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
