import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/household.dart';
import '../../models/pet.dart';
import '../../models/profile.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/pet_age.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _householdNameController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Household? _household;
  List<Pet> _pets = [];
  List<Profile> _members = [];
  bool _loading = true;
  bool _savingName = false;
  bool _savingHouseholdName = false;
  bool _savingPassword = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  final _newPetNameController = TextEditingController();
  DateTime? _newPetDateOfBirth;
  bool _addingPet = false;
  String? _savingPetId;
  String? _deletingPetId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _householdNameController.dispose();
    _newPetNameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      final profile = await auth.getProfile();
      final household = await auth.getHousehold();
      final members = await auth.getHouseholdMembers();
      final pets = household == null
          ? <Pet>[]
          : await ref.read(petsServiceProvider).getPets();

      if (mounted) {
        _nameController.text = profile?.displayName ?? '';
        _householdNameController.text = household?.name ?? '';
        setState(() {
          _household = household;
          _members = members;
          _pets = pets;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveDisplayName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingName = true);
    try {
      await ref.read(authServiceProvider).updateDisplayName(name);
      ref.invalidate(profileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name updated')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save name: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _saveHouseholdName() async {
    final name = _householdNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingHouseholdName = true);
    try {
      await ref.read(authServiceProvider).updateHouseholdName(name);
      ref.invalidate(householdProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Household name updated')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save household name: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingHouseholdName = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    setState(() => _savingPassword = true);
    try {
      await ref
          .read(authServiceProvider)
          .updatePassword(_newPasswordController.text);
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _addPet() async {
    final name = _newPetNameController.text.trim();
    final dateOfBirth = _newPetDateOfBirth;
    if (name.isEmpty || dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and date of birth.')),
      );
      return;
    }

    setState(() => _addingPet = true);
    try {
      await ref.read(petsServiceProvider).createPet(
            name: name,
            dateOfBirth: dateOfBirth,
          );
      ref.invalidate(petsProvider);
      _newPetNameController.clear();
      _newPetDateOfBirth = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pet added')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add pet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _addingPet = false);
    }
  }

  Future<void> _pickNewPetDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newPetDateOfBirth ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _newPetDateOfBirth = picked);
    }
  }

  void _copyInviteCode() {
    final code = _household?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied!')),
    );
  }

  Future<void> _signOut() async {
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUser?.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Household'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: 'Your profile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Display name',
                            hintText: 'e.g. Mom, Dad, Matt',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _savingName ? null : _saveDisplayName,
                          child: _savingName
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save name'),
                        ),
                        if (email != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(email, style: const TextStyle(fontSize: 15)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Password',
                    child: Form(
                      key: _passwordFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'New password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscureNewPassword = !_obscureNewPassword,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v != null && v.length >= 6 ? null : 'Min 6 characters',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm new password',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Min 6 characters';
                              }
                              if (v != _newPasswordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _savingPassword ? null : _changePassword,
                            child: _savingPassword
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Update password'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_household != null) ...[
                    _SectionCard(
                      title: 'Household',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _householdNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Household name',
                              hintText: "e.g. Pepper's Schedule",
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed:
                                _savingHouseholdName ? null : _saveHouseholdName,
                            child: _savingHouseholdName
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save household name'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Invite code',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.feedBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.feed),
                            ),
                            child: Text(
                              _household!.inviteCode,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _copyInviteCode,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy invite code'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Share this code so family members can sign up and join your household.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Pets (${_pets.length})',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Add each puppy or dog in your household. Ages update automatically from their date of birth.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: AppColors.textSecondary.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_pets.isEmpty)
                            Text(
                              'No pets yet.',
                              style: TextStyle(
                                color: AppColors.textSecondary.withValues(alpha: 0.9),
                              ),
                            )
                          else
                            ..._pets.map(
                              (pet) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PetEditorCard(
                                  pet: pet,
                                  saving: _savingPetId == pet.id,
                                  deleting: _deletingPetId == pet.id,
                                  onSave: (name, dateOfBirth) async {
                                    setState(() => _savingPetId = pet.id);
                                    try {
                                      await ref.read(petsServiceProvider).updatePet(
                                            id: pet.id,
                                            name: name,
                                            dateOfBirth: dateOfBirth,
                                          );
                                      ref.invalidate(petsProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Pet updated')),
                                        );
                                        await _load();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Could not save pet: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _savingPetId = null);
                                    }
                                  },
                                  onDelete: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove pet?'),
                                        content: Text(
                                          'Remove ${pet.name} from your household?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed != true || !mounted) return;

                                    setState(() => _deletingPetId = pet.id);
                                    try {
                                      await ref.read(petsServiceProvider).deletePet(pet.id);
                                      ref.invalidate(petsProvider);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Pet removed')),
                                        );
                                        await _load();
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Could not remove pet: $e')),
                                        );
                                      }
                                    } finally {
                                      if (mounted) setState(() => _deletingPetId = null);
                                    }
                                  },
                                ),
                              ),
                            ),
                          const Divider(height: 32),
                          Text(
                            'Add a pet',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPetNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              hintText: 'Pepper',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _pickNewPetDateOfBirth,
                            child: Text(
                              _newPetDateOfBirth == null
                                  ? 'Choose date of birth'
                                  : 'Born ${formatDateOfBirth(_newPetDateOfBirth!)}',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _addingPet ? null : _addPet,
                            child: Text(_addingPet ? 'Adding…' : 'Add pet'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Family members (${_members.length})',
                      child: Column(
                        children: _members.map((member) {
                          final isYou = member.id ==
                              ref.read(authServiceProvider).currentUser?.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.sleepBg,
                                  child: Text(
                                    member.displayName.isNotEmpty
                                        ? member.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.sleep,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (isYou)
                                        const Text(
                                          'You',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.potty,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: AppColors.train),
                    label: const Text(
                      'Sign out',
                      style: TextStyle(color: AppColors.train),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.train),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PetEditorCard extends StatefulWidget {
  const _PetEditorCard({
    required this.pet,
    required this.saving,
    required this.deleting,
    required this.onSave,
    required this.onDelete,
  });

  final Pet pet;
  final bool saving;
  final bool deleting;
  final Future<void> Function(String name, DateTime dateOfBirth) onSave;
  final Future<void> Function() onDelete;

  @override
  State<_PetEditorCard> createState() => _PetEditorCardState();
}

class _PetEditorCardState extends State<_PetEditorCard> {
  late final TextEditingController _nameController;
  late DateTime _dateOfBirth;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.pet.name);
    _dateOfBirth = widget.pet.dateOfBirth;
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
        color: AppColors.feedBg.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.feed.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _pickDateOfBirth,
            child: Text('Born ${formatDateOfBirth(_dateOfBirth)}'),
          ),
          const SizedBox(height: 8),
          Text(
            formatPetAge(_dateOfBirth),
            style: const TextStyle(
              color: AppColors.potty,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: widget.saving
                    ? null
                    : () => widget.onSave(_nameController.text, _dateOfBirth),
                child: Text(widget.saving ? 'Saving…' : 'Save'),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: widget.deleting ? null : widget.onDelete,
                child: Text(
                  widget.deleting ? 'Removing…' : 'Remove',
                  style: const TextStyle(color: AppColors.train),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
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
        style: const TextStyle(color: AppColors.train, fontSize: 13),
      ),
    );
  }
}
