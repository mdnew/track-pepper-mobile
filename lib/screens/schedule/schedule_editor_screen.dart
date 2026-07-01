import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/emoji_text.dart';

import '../../data/task_categories.dart';
import '../../models/pet.dart';
import '../../models/schedule_plan.dart';
import '../../models/schedule_task.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/species_theme.dart';
import '../../utils/pet_age.dart';
import '../../utils/schedule_plan.dart';
import '../../utils/schedule_time.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/schedule_block.dart';
import '../../widgets/section_divider.dart';

class ScheduleEditorScreen extends ConsumerStatefulWidget {
  const ScheduleEditorScreen({
    super.key,
    required this.pet,
    required this.householdId,
  });

  final Pet pet;
  final String householdId;

  @override
  ConsumerState<ScheduleEditorScreen> createState() =>
      _ScheduleEditorScreenState();
}

class _ScheduleEditorScreenState extends ConsumerState<ScheduleEditorScreen> {
  SchedulePlan? _plan;
  List<ScheduleTask> _tasks = [];
  String? _editingTaskId;
  bool _isCustomized = false;
  bool _loading = true;
  bool _saving = false;
  bool _resetting = false;
  bool _showResetConfirm = false;
  String? _deleteTaskId;
  String? _error;
  String? _message;

  SpeciesTheme get _theme => speciesTheme(widget.pet.species);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = ref.read(scheduleServiceProvider);
      final plans = await service.getPlans();
      var plan = resolvePlanForPet(plans, widget.pet, DateTime.now());

      late List<ScheduleTask> tasks;
      var isCustomized = false;
      final customTasks = await service.getValidCustomTasksForPet(widget.pet.id);
      if (customTasks != null) {
        tasks = customTasks;
        isCustomized = true;
      } else {
        final draft = await service.copyPlanToCustomDraft(
          pet: widget.pet,
          plans: plans,
          referenceDate: DateTime.now(),
        );
        plan = draft.plan ?? plan;
        tasks = draft.tasks;
      }

      if (!mounted) return;
      setState(() {
        _plan = plan;
        _tasks = sortTasksChronologically(tasks);
        _isCustomized = isCustomized;
        _editingTaskId = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _updateTask(String id, ScheduleTask updated) {
    setState(() {
      _tasks = [
        for (final task in _tasks) if (task.id == id) updated else task,
      ];
    });
  }

  void _handleCategoryChange(String id, String category) {
    final defaults = categoryDefaultsFor(category);
    final task = _tasks.firstWhere((item) => item.id == id);
    _updateTask(
      id,
      _copyTask(
        task,
        category: category,
        title: defaults.title,
        icon: defaults.icon,
        section: defaults.section,
      ),
    );
  }

  void _finishEdit() {
    setState(() {
      _tasks = sortTasksChronologically(_tasks);
      _editingTaskId = null;
    });
  }

  void _removeTask(String id) {
    setState(() {
      _tasks = _tasks.where((task) => task.id != id).toList();
      if (_editingTaskId == id) _editingTaskId = null;
      _deleteTaskId = null;
    });
  }

  void _requestDelete(String id) {
    if (id.startsWith('new-')) {
      _removeTask(id);
      return;
    }
    setState(() => _deleteTaskId = id);
  }

  void _cancelEdit(String id) {
    if (id.startsWith('new-')) {
      _removeTask(id);
      return;
    }
    setState(() => _editingTaskId = null);
  }

  void _startAddTask() {
    final defaults = categoryDefaultsFor('potty');
    final task = ScheduleTask(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      planId: null,
      petId: widget.pet.id,
      sortOrder: _tasks.length,
      timeLabel: '8:00 AM',
      category: 'potty',
      title: defaults.title,
      subtitle: null,
      icon: defaults.icon,
      section: defaults.section,
      isCustom: true,
    );
    setState(() {
      _tasks = [..._tasks, task];
      _editingTaskId = task.id;
    });
  }

  Future<void> _save() async {
    if (_tasks.any((task) => task.title.trim().isEmpty)) {
      setState(() {
        _error = 'Each task needs a title.';
        _message = null;
      });
      return;
    }
    if (_tasks.any((task) => validateTimeLabel(task.timeLabel) == null)) {
      setState(() {
        _error = 'Each task needs a time.';
        _message = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _message = null;
    });

    try {
      final normalizedTasks = [
        for (var i = 0; i < _tasks.length; i++)
          _copyTask(
            _tasks[i],
            sortOrder: i,
            timeLabel:
                validateTimeLabel(_tasks[i].timeLabel.trim()) ??
                _tasks[i].timeLabel.trim(),
            title: _tasks[i].title.trim(),
            subtitle: _tasks[i].subtitle?.trim().isEmpty ?? true
                ? null
                : _tasks[i].subtitle!.trim(),
            isCustom: true,
          ),
      ];

      final userId = ref.read(authServiceProvider).currentUserId;
      if (userId == null) throw StateError('Not signed in');

      await ref.read(scheduleServiceProvider).saveCustomSchedule(
            petId: widget.pet.id,
            basePlanId: _plan?.id,
            tasks: normalizedTasks,
            userId: userId,
          );
      ref.read(scheduleRevisionProvider.notifier).state++;

      if (!mounted) return;
      setState(() {
        _isCustomized = true;
        _editingTaskId = null;
        _message = 'Schedule saved.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _resetting = true;
      _error = null;
      _message = null;
    });

    try {
      await ref
          .read(scheduleServiceProvider)
          .resetScheduleToDefault(widget.pet.id);
      ref.read(scheduleRevisionProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        _showResetConfirm = false;
        _editingTaskId = null;
        _message = 'Schedule reset to default.';
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  ScheduleTask _copyTask(
    ScheduleTask source, {
    String? timeLabel,
    String? category,
    String? title,
    String? subtitle,
    String? icon,
    String? section,
    int? sortOrder,
    bool? isCustom,
  }) {
    return ScheduleTask(
      id: source.id,
      planId: source.planId,
      petId: source.petId ?? widget.pet.id,
      sortOrder: sortOrder ?? source.sortOrder,
      timeLabel: timeLabel ?? source.timeLabel,
      category: category ?? source.category,
      title: title ?? source.title,
      subtitle: subtitle ?? source.subtitle,
      icon: icon ?? source.icon,
      section: section ?? source.section,
      isCustom: isCustom ?? source.isCustom,
    );
  }

  Future<bool> _confirmDeleteTask(ScheduleTask task) async {
    if (task.id.startsWith('new-')) return true;

    final label =
        task.title.trim().isEmpty ? 'This task' : task.title.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"$label" will be removed from this schedule.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.train),
            child: const Text('Delete task'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  List<Widget> _buildTaskList() {
    final widgets = <Widget>[];
    String? currentSection;

    for (final task in _tasks) {
      if (task.section != currentSection) {
        currentSection = task.section;
        widgets.add(
          SectionDivider(label: currentSection, color: _theme.divider),
        );
      }

      if (_editingTaskId == task.id) {
        widgets.add(
          _TaskEditForm(
            task: task,
            onUpdate: (patch) {
              _updateTask(task.id, _copyTaskFromPatch(task, patch));
            },
            onCategoryChange: (category) =>
                _handleCategoryChange(task.id, category),
            onDelete: () => _requestDelete(task.id),
            onDone: _finishEdit,
            onCancel: () => _cancelEdit(task.id),
          ),
        );
      } else {
        widgets.add(
          Dismissible(
            key: ValueKey(task.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.trainBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.train,
              ),
            ),
            confirmDismiss: (_) => _confirmDeleteTask(task),
            onDismissed: (_) => _removeTask(task.id),
            child: ScheduleBlock(
              task: task,
              species: widget.pet.species,
              theme: _theme,
              readOnly: true,
              onEdit: () => setState(() => _editingTaskId = task.id),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    ScheduleTask? deleteTask;
    if (_deleteTaskId != null) {
      for (final task in _tasks) {
        if (task.id == _deleteTaskId) {
          deleteTask = task;
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit schedule'),
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 12),
                ],
                if (_message != null) ...[
                  _SuccessBanner(message: _message!),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Tasks',
                          style: AppFonts.nunito(
                            fontSize: AppFonts.sz(18),
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        EmojiAwareText(
                          '${formatPetSummaryWithPlan(widget.pet, _plan)}'
                          '${_isCustomized ? ' · customized' : ''}',
                          style: AppFonts.nunito(
                            fontSize: AppFonts.sz(14),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap Edit on a task to change its time or description. '
                          'Changes apply to future days only. Use Reset to default '
                          'below to restore the original age-based schedule.',
                          style: TextStyle(
                            fontSize: AppFonts.sz(13),
                            height: 1.5,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._buildTaskList(),
                        if (_editingTaskId == null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: _startAddTask,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Add task'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving || _tasks.isEmpty || _editingTaskId != null
                      ? null
                      : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save schedule'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed:
                      _resetting || _editingTaskId != null ? null : () {
                    setState(() => _showResetConfirm = true);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_resetting ? 'Resetting…' : 'Reset to default'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.header,
                    ),
                    child: Text(
                      'Back to settings',
                      style: AppFonts.nunito(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.header,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ConfirmDialog(
            open: _showResetConfirm,
            title: 'Reset to default?',
            message:
                'This restores the original age-based schedule. Your custom tasks will be removed.',
            confirmLabel: 'Reset to default',
            confirmingLabel: 'Resetting…',
            confirming: _resetting,
            onCancel: () {
              if (!_resetting) setState(() => _showResetConfirm = false);
            },
            onConfirm: _reset,
          ),
          ConfirmDialog(
            open: deleteTask != null,
            title: 'Delete task?',
            message: deleteTask == null
                ? ''
                : '"${deleteTask.title.trim().isEmpty ? 'This task' : deleteTask.title.trim()}" '
                    'will be removed from this schedule.',
            confirmLabel: 'Delete task',
            onCancel: () => setState(() => _deleteTaskId = null),
            onConfirm: () {
              if (_deleteTaskId != null) _removeTask(_deleteTaskId!);
            },
          ),
        ],
      ),
    );
  }
}

class TaskPatch {
  const TaskPatch({
    this.timeLabel,
    this.category,
    this.title,
    this.subtitle,
    this.icon,
    this.section,
  });

  final String? timeLabel;
  final String? category;
  final String? title;
  final String? subtitle;
  final String? icon;
  final String? section;
}

ScheduleTask _copyTaskFromPatch(ScheduleTask task, TaskPatch patch) {
  return ScheduleTask(
    id: task.id,
    planId: task.planId,
    petId: task.petId,
    sortOrder: task.sortOrder,
    timeLabel: patch.timeLabel ?? task.timeLabel,
    category: patch.category ?? task.category,
    title: patch.title ?? task.title,
    subtitle: patch.subtitle ?? task.subtitle,
    icon: patch.icon ?? task.icon,
    section: patch.section ?? task.section,
    isCustom: task.isCustom,
  );
}

class _TaskEditForm extends StatefulWidget {
  const _TaskEditForm({
    required this.task,
    required this.onUpdate,
    required this.onCategoryChange,
    required this.onDelete,
    required this.onDone,
    required this.onCancel,
  });

  final ScheduleTask task;
  final void Function(TaskPatch patch) onUpdate;
  final ValueChanged<String> onCategoryChange;
  final VoidCallback onDelete;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<_TaskEditForm> createState() => _TaskEditFormState();
}

class _TaskEditFormState extends State<_TaskEditForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  String? _timeError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _subtitleController =
        TextEditingController(text: widget.task.subtitle ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final initial = timeOfDayFromLabel(widget.task.timeLabel) ??
        const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() => _timeError = null);
    widget.onUpdate(TaskPatch(timeLabel: timeLabelFromTimeOfDay(picked)));
  }

  void _handleDone() {
    if (validateTimeLabel(widget.task.timeLabel) == null) {
      setState(() => _timeError = 'Pick a time.');
      return;
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E7E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Time',
                      style: TextStyle(
                        fontSize: AppFonts.sz(12),
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: _pickTime,
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        side: BorderSide(
                          color: _timeError == null
                              ? const Color(0xFFE7E7E7)
                              : AppColors.train,
                        ),
                      ),
                      child: Text(widget.task.timeLabel),
                    ),
                    if (_timeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _timeError!,
                          style: TextStyle(
                            color: AppColors.train,
                            fontSize: AppFonts.sz(12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Category',
                      style: TextStyle(
                        fontSize: AppFonts.sz(12),
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      key: ValueKey(widget.task.category),
                      initialValue: widget.task.category,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        for (final category in taskCategories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.onCategoryChange(value);
                          _titleController.text =
                              categoryDefaultsFor(value).title;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (value) => widget.onUpdate(TaskPatch(title: value)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _subtitleController,
            decoration: const InputDecoration(labelText: 'Subtitle (optional)'),
            onChanged: (value) => widget.onUpdate(TaskPatch(subtitle: value)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleDone,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.train,
              side: const BorderSide(color: AppColors.train),
            ),
            child: const Text('Delete task'),
          ),
        ],
      ),
    );
  }
}

class _SuccessBanner extends StatelessWidget {
  const _SuccessBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.pottyBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.potty, fontSize: AppFonts.sz(13)),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.trainBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: AppColors.train, fontSize: AppFonts.sz(13)),
      ),
    );
  }
}

