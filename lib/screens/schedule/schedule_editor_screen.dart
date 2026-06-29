import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/roadmap_demo_store.dart';
import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({
    super.key,
    required this.pet,
    required this.householdId,
  });

  final Pet pet;
  final String householdId;

  @override
  ConsumerState<ScheduleEditorScreen> createState() => _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  SchedulePlan? _basePlan;
  List<ScheduleTask> _tasks = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ref.read(scheduleServiceProvider);
    final plans = await service.getPlans();
    final schedule = await service.getScheduleForPet(
      pet: widget.pet,
      plans: plans,
      referenceDate: DateTime.now(),
    );
    if (!mounted) return;
    setState(() {
      _basePlan = schedule.plan;
      _tasks = schedule.tasks
          .map(
            (task) => ScheduleTask(
              id: task.id,
              planId: task.planId,
              petId: task.petId ?? widget.pet.id,
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
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(scheduleServiceProvider).saveCustomSchedule(
            petId: widget.pet.id,
            basePlanId: _basePlan?.id,
            tasks: _tasks,
            userId: ref.read(authServiceProvider).currentUserId ?? demoUserId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom schedule saved')),
      );
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    await ref.read(scheduleServiceProvider).resetScheduleToDefault(widget.pet.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule reset to default')),
    );
    await _load();
  }

  void _addTask() {
    setState(() {
      _tasks = [
        ..._tasks,
        ScheduleTask(
          id: 'new-${DateTime.now().microsecondsSinceEpoch}',
          planId: null,
          petId: widget.pet.id,
          sortOrder: _tasks.length,
          timeLabel: '9:00 AM',
          category: 'note',
          title: 'New task',
          subtitle: null,
          icon: '📝',
          section: 'Custom',
          isCustom: true,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.pet.name} schedule'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Base plan: ${_basePlan?.name ?? 'None'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _tasks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TaskEditorTile(
                      task: _tasks[i],
                      onChanged: (updated) {
                        setState(() {
                          _tasks = [
                            for (var j = 0; j < _tasks.length; j++)
                              j == i ? updated : _tasks[j],
                          ];
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _tasks = [
                            for (var j = 0; j < _tasks.length; j++)
                              if (j != i) _tasks[j],
                          ].asMap().entries.map((entry) {
                            final task = entry.value;
                            return ScheduleTask(
                              id: task.id,
                              planId: task.planId,
                              petId: task.petId,
                              sortOrder: entry.key,
                              timeLabel: task.timeLabel,
                              category: task.category,
                              title: task.title,
                              subtitle: task.subtitle,
                              icon: task.icon,
                              section: task.section,
                              isCustom: true,
                            );
                          }).toList();
                        });
                      },
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: _addTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add task'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save custom schedule'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Reset to default'),
                ),
              ],
            ),
    );
  }
}

class _TaskEditorTile extends StatelessWidget {
  const _TaskEditorTile({
    required this.task,
    required this.onChanged,
    required this.onDelete,
  });

  final ScheduleTask task;
  final ValueChanged<ScheduleTask> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: TextEditingController(text: task.title),
            decoration: const InputDecoration(labelText: 'Task title'),
            onChanged: (value) {
              onChanged(_copy(task, title: value));
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: task.timeLabel),
            decoration: const InputDecoration(labelText: 'Time label'),
            onChanged: (value) {
              onChanged(_copy(task, timeLabel: value));
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: task.section),
            decoration: const InputDecoration(labelText: 'Section'),
            onChanged: (value) {
              onChanged(_copy(task, section: value));
            },
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDelete,
              child: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }

  ScheduleTask _copy(
    ScheduleTask source, {
    String? title,
    String? timeLabel,
    String? section,
  }) {
    return ScheduleTask(
      id: source.id,
      planId: source.planId,
      petId: source.petId,
      sortOrder: source.sortOrder,
      timeLabel: timeLabel ?? source.timeLabel,
      category: source.category,
      title: title ?? source.title,
      subtitle: source.subtitle,
      icon: source.icon,
      section: section ?? source.section,
      isCustom: source.isCustom,
    );
  }
}
