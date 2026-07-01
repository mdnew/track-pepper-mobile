import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_text_styles.dart';
import 'emoji_text.dart';

import '../models/pet.dart';
import '../providers/providers.dart';
import '../screens/schedule/schedule_editor_screen.dart';
import '../theme/app_theme.dart';
import '../utils/pet_age.dart';
import '../widgets/confirm_dialog.dart';

class _PetScheduleInfo {
  const _PetScheduleInfo({required this.label, this.taskCount});

  final String label;
  final int? taskCount;
}

class PetsSection extends ConsumerStatefulWidget {
  const PetsSection({
    super.key,
    required this.householdId,
    this.canManagePets = true,
    required this.onMessage,
    required this.onError,
  });

  final String householdId;
  final bool canManagePets;
  final ValueChanged<String> onMessage;
  final ValueChanged<String?> onError;

  @override
  ConsumerState<PetsSection> createState() => _PetsSectionState();
}

class _PetsSectionState extends ConsumerState<PetsSection> {
  List<Pet> _pets = const [];
  Map<String, _PetScheduleInfo> _scheduleSummaries = const {};
  String? _editingPetId;
  String? _savingPetId;
  String? _deletingPetId;
  String? _removeConfirmPetId;
  bool _loading = true;
  bool _showAddForm = false;
  bool _adding = false;
  final _newPetNameController = TextEditingController();
  DateTime? _newPetDateOfBirth;
  PetSpecies _newPetSpecies = PetSpecies.dog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newPetNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final petsService = ref.read(petsServiceProvider);
      final scheduleService = ref.read(scheduleServiceProvider);
      final pets = await petsService.getPets(householdId: widget.householdId);
      final plans = await scheduleService.getPlans();
      final summaries = <String, _PetScheduleInfo>{};

      for (final pet in pets) {
        final meta = await scheduleService.getPetScheduleMeta(pet.id);
        if (meta?.isCustomized == true) {
          final tasks = await scheduleService.getCustomTasksForPet(pet.id);
          summaries[pet.id] = _PetScheduleInfo(
            label: 'Custom schedule',
            taskCount: tasks.length,
          );
        } else {
          final schedule = await scheduleService.getScheduleForPet(
            pet: pet,
            plans: plans,
          );
          summaries[pet.id] = schedule.plan == null
              ? const _PetScheduleInfo(label: 'No schedule yet')
              : _PetScheduleInfo(
                  label: '${schedule.plan!.emoji} ${schedule.plan!.name}',
                  taskCount: schedule.tasks.length,
                );
        }
      }

      if (mounted) {
        setState(() {
          _pets = pets;
          _scheduleSummaries = summaries;
          _loading = false;
          _editingPetId = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        widget.onError(error.toString());
      }
    }
  }

  String _formatScheduleLine(_PetScheduleInfo info) {
    if (info.taskCount == null) return info.label;
    return '${info.label} · ${info.taskCount} tasks';
  }

  Future<void> _addPet() async {
    final name = _newPetNameController.text.trim();
    final dateOfBirth = _newPetDateOfBirth;
    if (name.isEmpty || dateOfBirth == null) {
      widget.onError('Enter a name and date of birth for the new pet.');
      return;
    }

    setState(() => _adding = true);
    widget.onError(null);
    try {
      await ref.read(petsServiceProvider).createPet(
            householdId: widget.householdId,
            name: name,
            dateOfBirth: dateOfBirth,
            species: _newPetSpecies,
          );
      ref.invalidate(petsProvider);
      ref.invalidate(petsByHouseholdProvider);
      _newPetNameController.clear();
      _newPetDateOfBirth = null;
      _newPetSpecies = PetSpecies.dog;
      setState(() => _showAddForm = false);
      await _load();
      widget.onMessage('Pet added.');
    } catch (error) {
      widget.onError(error.toString());
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final removePet = _removeConfirmPetId == null
        ? null
        : _pets.where((pet) => pet.id == _removeConfirmPetId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HouseholdSubsectionTitle(title: 'Pets'),
        Text(
          'Add each dog or cat in your household. Ages update automatically from their date of birth.',
          style: TextStyle(
            fontSize: AppFonts.sz(13),
            height: 1.5,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          if (_pets.isNotEmpty)
            ..._pets.map(
              (pet) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PetCard(
                  pet: pet,
                  scheduleInfo: _scheduleSummaries[pet.id] ??
                      const _PetScheduleInfo(label: 'No schedule yet'),
                  editing: _editingPetId == pet.id,
                  saving: _savingPetId == pet.id,
                  deleting: _deletingPetId == pet.id,
                  formatScheduleLine: _formatScheduleLine,
                  onEdit: () => setState(() => _editingPetId = pet.id),
                  onCancel: () => setState(() => _editingPetId = null),
                  onSave: (name, dateOfBirth, species) async {
                    setState(() => _savingPetId = pet.id);
                    widget.onError(null);
                    try {
                      await ref.read(petsServiceProvider).updatePet(
                            id: pet.id,
                            name: name,
                            dateOfBirth: dateOfBirth,
                            species: species,
                          );
                      ref.invalidate(petsProvider);
                      ref.invalidate(petsByHouseholdProvider);
                      await _load();
                      widget.onMessage('Pet updated.');
                    } catch (error) {
                      widget.onError(error.toString());
                    } finally {
                      if (mounted) setState(() => _savingPetId = null);
                    }
                  },
                  onRemove: () => setState(() => _removeConfirmPetId = pet.id),
                  onScheduleEdit: widget.canManagePets
                      ? () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ScheduleEditorScreen(
                                pet: pet,
                                householdId: widget.householdId,
                              ),
                            ),
                          );
                          await _load();
                        }
                      : null,
                ),
              ),
            ),
          if (widget.canManagePets)
            _showAddForm
                ? _AddPetForm(
                    nameController: _newPetNameController,
                    dateOfBirth: _newPetDateOfBirth,
                    species: _newPetSpecies,
                    adding: _adding,
                    onPickDate: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _newPetDateOfBirth ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() => _newPetDateOfBirth = picked);
                      }
                    },
                    onSpeciesChanged: (species) =>
                        setState(() => _newPetSpecies = species),
                    onCancel: () {
                      _newPetNameController.clear();
                      _newPetDateOfBirth = null;
                      _newPetSpecies = PetSpecies.dog;
                      setState(() => _showAddForm = false);
                    },
                    onSubmit: _addPet,
                  )
                : SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => setState(() => _showAddForm = true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppColors.header,
                        side: const BorderSide(color: AppColors.header),
                      ),
                      child: const Text('Add pet'),
                    ),
                  ),
        ],
        ConfirmDialog(
          open: _removeConfirmPetId != null,
          title: 'Remove pet?',
          message: removePet == null
              ? ''
              : '${removePet.name} will be removed from your household, including their schedule and completion history.',
          confirmLabel: 'Remove pet',
          confirmingLabel: 'Removing…',
          confirming: _deletingPetId == _removeConfirmPetId,
          onCancel: () {
            if (_deletingPetId == null) {
              setState(() => _removeConfirmPetId = null);
            }
          },
          onConfirm: () async {
            final petId = _removeConfirmPetId;
            if (petId == null) return;
            setState(() => _deletingPetId = petId);
            widget.onError(null);
            try {
              await ref.read(petsServiceProvider).deletePet(petId);
              ref.read(scheduleServiceProvider).invalidateScheduleCache(petId: petId);
              ref.invalidate(petsProvider);
              ref.invalidate(petsByHouseholdProvider);
              setState(() => _removeConfirmPetId = null);
              await _load();
              widget.onMessage('Pet removed.');
            } catch (error) {
              widget.onError(error.toString());
            } finally {
              if (mounted) setState(() => _deletingPetId = null);
            }
          },
        ),
      ],
    );
  }
}

class _HouseholdSubsectionTitle extends StatelessWidget {
  const _HouseholdSubsectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppFonts.nunito(
          fontSize: AppFonts.sz(14),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PetCard extends StatefulWidget {
  const _PetCard({
    required this.pet,
    required this.scheduleInfo,
    required this.editing,
    required this.saving,
    required this.deleting,
    required this.formatScheduleLine,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
    required this.onRemove,
    this.onScheduleEdit,
  });

  final Pet pet;
  final _PetScheduleInfo scheduleInfo;
  final bool editing;
  final bool saving;
  final bool deleting;
  final String Function(_PetScheduleInfo info) formatScheduleLine;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function(String name, DateTime dateOfBirth, PetSpecies species)
      onSave;
  final VoidCallback onRemove;
  final Future<void> Function()? onScheduleEdit;

  @override
  State<_PetCard> createState() => _PetCardState();
}

class _PetCardState extends State<_PetCard> {
  late final TextEditingController _nameController;
  late DateTime _dateOfBirth;
  late PetSpecies _species;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _dateOfBirth = widget.pet.dateOfBirth;
    _species = widget.pet.species;
  }

  @override
  void didUpdateWidget(covariant _PetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.editing) {
      _nameController.text = widget.pet.name;
      _dateOfBirth = widget.pet.dateOfBirth;
      _species = widget.pet.species;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC9A87C).withValues(alpha: 0.35)),
      ),
      child: widget.editing ? _buildEditMode() : _buildReadMode(),
    );
  }

  Widget _buildReadMode() {
    final scheduleLine = widget.formatScheduleLine(widget.scheduleInfo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EmojiAwareText(
                    formatPetSummary(widget.pet),
                    style: AppFonts.nunito(
                      fontSize: AppFonts.sz(15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Born ${formatDateOfBirth(widget.pet.dateOfBirth)}',
                    style: TextStyle(
                      fontSize: AppFonts.sz(13),
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit ${widget.pet.name}',
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmojiAwareText(
              scheduleLine,
              style: TextStyle(
                fontSize: AppFonts.sz(12),
                height: 1.4,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            if (widget.scheduleInfo.taskCount != null &&
                widget.onScheduleEdit != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => widget.onScheduleEdit!(),
                child: Text(
                  'Edit Schedule',
                  style: AppFonts.nunito(
                    fontSize: AppFonts.sz(12),
                    fontWeight: FontWeight.w700,
                    color: AppColors.header,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.header,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SpeciesPicker(
          value: _species,
          onChanged: (species) => setState(() => _species = species),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        Text(
          'Date of birth',
          style: TextStyle(
            fontSize: AppFonts.sz(13),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: _pickDateOfBirth,
          child: Text('Born ${formatDateOfBirth(_dateOfBirth)}'),
        ),
        const SizedBox(height: 8),
        Text(
          formatPetAge(_dateOfBirth),
          style: TextStyle(
            color: AppColors.potty,
            fontWeight: FontWeight.w700,
            fontSize: AppFonts.sz(12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.saving || widget.deleting ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.saving
                    ? null
                    : () => widget.onSave(
                          _nameController.text,
                          _dateOfBirth,
                          _species,
                        ),
                child: Text(widget.saving ? 'Saving…' : 'Save'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: widget.deleting ? null : widget.onRemove,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.train,
            side: const BorderSide(color: AppColors.train),
          ),
          child: Text(widget.deleting ? 'Removing…' : 'Remove pet'),
        ),
      ],
    );
  }
}

class _SpeciesPicker extends StatelessWidget {
  const _SpeciesPicker({required this.value, required this.onChanged});

  final PetSpecies value;
  final ValueChanged<PetSpecies> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type',
          style: TextStyle(
            fontSize: AppFonts.sz(13),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _SpeciesOption(
                label: '🐶 Dog',
                selected: value == PetSpecies.dog,
                onTap: () => onChanged(PetSpecies.dog),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SpeciesOption(
                label: '🐱 Cat',
                selected: value == PetSpecies.cat,
                onTap: () => onChanged(PetSpecies.cat),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeciesOption extends StatelessWidget {
  const _SpeciesOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? const Color(0xFFFFFAF5) : Colors.white,
        foregroundColor: selected ? AppColors.header : AppColors.textSecondary,
        side: BorderSide(
          color: selected
              ? AppColors.header
              : const Color(0xFFC9A87C).withValues(alpha: 0.4),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: EmojiAwareText(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AddPetForm extends StatelessWidget {
  const _AddPetForm({
    required this.nameController,
    required this.dateOfBirth,
    required this.species,
    required this.adding,
    required this.onPickDate,
    required this.onSpeciesChanged,
    required this.onCancel,
    required this.onSubmit,
  });

  final TextEditingController nameController;
  final DateTime? dateOfBirth;
  final PetSpecies species;
  final bool adding;
  final VoidCallback onPickDate;
  final ValueChanged<PetSpecies> onSpeciesChanged;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add a pet',
          style: AppFonts.nunito(
            fontSize: AppFonts.sz(15),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        _SpeciesPicker(value: species, onChanged: onSpeciesChanged),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Pepper',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Date of birth',
          style: TextStyle(
            fontSize: AppFonts.sz(13),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton(
          onPressed: onPickDate,
          child: Text(
            dateOfBirth == null
                ? 'Choose date of birth'
                : 'Born ${formatDateOfBirth(dateOfBirth!)}',
          ),
        ),
        if (dateOfBirth != null) ...[
          const SizedBox(height: 8),
          Text(
            formatPetAge(dateOfBirth!),
            style: TextStyle(
              color: AppColors.potty,
              fontWeight: FontWeight.w700,
              fontSize: AppFonts.sz(12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: adding ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: adding ? null : onSubmit,
                child: Text(adding ? 'Adding…' : 'Add pet'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
