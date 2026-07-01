import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_text_styles.dart';

import '../../config/recommendations.dart';
import '../../models/household.dart';
import '../../models/household_member.dart';
import '../../models/household_membership.dart';
import '../../models/household_role.dart';
import '../../models/pet.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/analytics.dart';
import '../../utils/guest_access.dart';
import '../../utils/local_catalog_cache.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/household_selector.dart';
import '../../widgets/pets_section.dart';
import '../../widgets/recommendations_section.dart';

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
  final _guestEmailController = TextEditingController();
  final Set<int> _guestDays = {};
  DateTime? _guestFromDate;
  DateTime? _guestUntilDate;
  Household? _household;
  List<Pet> _pets = [];
  List<HouseholdMember> _members = [];
  List<HouseholdMember> _guests = [];
  List<HouseholdMembership> _memberships = [];
  Map<String, List<Pet>> _petsByHouseholdId = {};
  String? _activeHouseholdId;
  HouseholdRole? _currentRole;
  bool _loading = true;
  bool _savingName = false;
  bool _savingHouseholdName = false;
  bool _savingPassword = false;
  bool _showGuestForm = false;
  bool _addingGuest = false;
  bool _showLeaveConfirm = false;
  bool _leaving = false;
  String? _editingMemberId;
  HouseholdRole _editMemberRole = HouseholdRole.member;
  bool _savingMemberRole = false;
  String? _editingGuestId;
  DateTime? _editGuestFromDate;
  DateTime? _editGuestUntilDate;
  final Set<int> _editGuestDays = {};
  bool _savingGuestAccess = false;
  String? _message;
  bool _editingName = false;
  bool _editingHouseholdName = false;
  bool _editingPassword = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Analytics.trackPageView('/settings');
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _householdNameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _guestEmailController.dispose();
    super.dispose();
  }

  bool get _canManage =>
      _currentRole == HouseholdRole.owner || _currentRole == HouseholdRole.admin;
  bool get _isGuest => _currentRole == HouseholdRole.guest;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      final profile = await auth.getProfile();
      final memberships = await auth.getMemberships();
      final activeHouseholdId = await ref.read(activeHouseholdIdProvider.future);
      if (activeHouseholdId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final household = await auth.getHousehold(activeHouseholdId);
      final role = await auth.getCurrentRole(activeHouseholdId);
      final members = role == HouseholdRole.guest
          ? <HouseholdMember>[]
          : await auth.getHouseholdMembers(activeHouseholdId);
      final guests = role == HouseholdRole.owner ||
              role == HouseholdRole.admin ||
              role == HouseholdRole.guest
          ? await auth.getGuestMembers(activeHouseholdId)
          : <HouseholdMember>[];
      final petsByHousehold = await ref.read(petsByHouseholdProvider.future);
      final pets = petsByHousehold[activeHouseholdId] ?? <Pet>[];

      if (mounted) {
        _nameController.text = profile?.displayName ?? '';
        _householdNameController.text = household?.name ?? '';
        setState(() {
          _household = household;
          _members = members;
          _guests = guests;
          _memberships = memberships;
          _petsByHouseholdId = petsByHousehold;
          _activeHouseholdId = activeHouseholdId;
          _currentRole = role;
          _pets = pets;
          _loading = false;
          _showGuestForm = false;
          _editingName = false;
          _editingHouseholdName = false;
          _editingPassword = false;
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
        setState(() {
          _editingName = false;
          _message = 'Display name updated.';
        });
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
    if (_activeHouseholdId == null) return;
    final name = _householdNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _savingHouseholdName = true);
    try {
      await ref
          .read(authServiceProvider)
          .updateHouseholdName(_activeHouseholdId!, name);
      ref.invalidate(householdProvider);
      ref.invalidate(membershipsProvider);
      ref.invalidate(petsByHouseholdProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Household name updated')),
        );
        setState(() => _editingHouseholdName = false);
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
        setState(() => _editingPassword = false);
        TextInput.finishAutofillContext(shouldSave: true);
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

  void _copyInviteCode() {
    final code = _household?.inviteCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _message = 'Invite code copied!');
  }

  Future<void> _switchHousehold(String householdId) async {
    await ref.read(authServiceProvider).setActiveHousehold(householdId);
    ref.invalidate(activeHouseholdIdProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(petsProvider);
    ref.invalidate(petsByHouseholdProvider);
    await _load();
  }

  bool _canRemove(HouseholdRole targetRole) {
    if (!_canManage) return false;
    if (_currentRole == HouseholdRole.admin &&
        (targetRole == HouseholdRole.owner || targetRole == HouseholdRole.admin)) {
      return false;
    }
    return true;
  }

  bool _canEditMemberRole(HouseholdMember member, String? myUserId) {
    if (_currentRole != HouseholdRole.owner) return false;
    if (member.userId == myUserId) return false;
    return member.role == HouseholdRole.member ||
        member.role == HouseholdRole.admin;
  }

  void _startEditMember(HouseholdMember member) {
    setState(() {
      _editingMemberId = member.userId;
      _editMemberRole = member.role == HouseholdRole.admin
          ? HouseholdRole.admin
          : HouseholdRole.member;
    });
  }

  void _cancelEditMember() {
    setState(() => _editingMemberId = null);
  }

  Future<void> _saveMemberRole() async {
    if (_editingMemberId == null || _activeHouseholdId == null) return;

    setState(() => _savingMemberRole = true);
    try {
      await ref.read(authServiceProvider).setMemberRole(
            _activeHouseholdId!,
            _editingMemberId!,
            _editMemberRole,
          );
      setState(() {
        _editingMemberId = null;
        _message = 'Role updated.';
      });
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingMemberRole = false);
    }
  }

  Future<bool> _confirmRemoveMemberSwipe(HouseholdMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          member.role == HouseholdRole.guest
              ? 'Remove guest?'
              : 'Remove member?',
        ),
        content: Text(
          member.role == HouseholdRole.guest
              ? '${member.displayName} will lose guest access to this household.'
              : '${member.displayName} will be removed from this household.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.train),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _removeMemberDirect(HouseholdMember member) async {
    if (_activeHouseholdId == null) return;

    try {
      await ref
          .read(authServiceProvider)
          .removeMember(_activeHouseholdId!, member.userId);
      setState(() => _message = '${member.displayName} removed.');
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _confirmLeaveHousehold() async {
    if (_activeHouseholdId == null) return;

    setState(() => _leaving = true);
    try {
      await ref.read(authServiceProvider).leaveHousehold(_activeHouseholdId!);
      setState(() => _showLeaveConfirm = false);
      ref.invalidate(profileProvider);
      ref.invalidate(activeHouseholdIdProvider);
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _leaveHousehold() async {
    if (_activeHouseholdId == null) return;
    if (_currentRole == HouseholdRole.owner) {
      setState(() => _error = "Owners can't leave a household they own.");
      return;
    }
    setState(() => _showLeaveConfirm = true);
  }

  Future<void> _pickGuestFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _guestFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _guestFromDate = picked);
    }
  }

  Future<void> _pickGuestUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _guestUntilDate ?? _guestFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _guestUntilDate = picked);
    }
  }

  void _cancelGuestForm() {
    _guestEmailController.clear();
    _guestFromDate = null;
    _guestUntilDate = null;
    _guestDays.clear();
    setState(() => _showGuestForm = false);
  }

  void _startEditGuest(HouseholdMember guest) {
    setState(() {
      _showGuestForm = false;
      _editingGuestId = guest.userId;
      _editGuestFromDate = guest.validFrom;
      _editGuestUntilDate = guest.validUntil;
      _editGuestDays
        ..clear()
        ..addAll(guest.validDaysOfWeek ?? const []);
    });
  }

  void _cancelEditGuest() {
    setState(() {
      _editingGuestId = null;
      _editGuestFromDate = null;
      _editGuestUntilDate = null;
      _editGuestDays.clear();
    });
  }

  Future<void> _saveGuestAccess() async {
    if (_editingGuestId == null ||
        _activeHouseholdId == null ||
        _editGuestFromDate == null ||
        _editGuestUntilDate == null) {
      setState(() => _error = 'Guest date range is required.');
      return;
    }

    setState(() => _savingGuestAccess = true);
    try {
      await ref.read(authServiceProvider).updateGuestAccess(
            _activeHouseholdId!,
            _editingGuestId!,
            formatGuestAccessDate(_editGuestFromDate!),
            formatGuestAccessDate(_editGuestUntilDate!),
            _editGuestDays.isEmpty
                ? null
                : (_editGuestDays.toList()..sort()),
          );
      setState(() {
        _editingGuestId = null;
        _message = 'Guest access updated.';
      });
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingGuestAccess = false);
    }
  }

  Future<void> _pickEditGuestFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editGuestFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _editGuestFromDate = picked);
    }
  }

  Future<void> _pickEditGuestUntilDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _editGuestUntilDate ?? _editGuestFromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _editGuestUntilDate = picked);
    }
  }

  Future<void> _addGuest() async {
    if (_activeHouseholdId == null) return;
    final email = _guestEmailController.text.trim();
    if (email.isEmpty || _guestFromDate == null || _guestUntilDate == null) {
      setState(() => _error = 'Guest email and date range are required.');
      return;
    }

    setState(() => _addingGuest = true);
    try {
      await ref.read(authServiceProvider).addGuestByEmail(
            _activeHouseholdId!,
            email,
            formatGuestAccessDate(_guestFromDate!),
            formatGuestAccessDate(_guestUntilDate!),
            _guestDays.isEmpty
                ? null
                : (_guestDays.toList()..sort()),
          );
      _cancelGuestForm();
      setState(() => _message = 'Guest access added.');
      await _load();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _addingGuest = false);
    }
  }

  Future<void> _signOut() async {
    ref.read(scheduleServiceProvider).invalidateScheduleCache();
    await clearLocalCatalogCache();
    await ref.read(authServiceProvider).signOut();
    ref.invalidate(profileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.read(authServiceProvider).currentUserEmail;
    final myUserId = ref.read(authServiceProvider).currentUserId;
    HouseholdMember? myGuest;
    for (final guest in _guests) {
      if (guest.userId == myUserId) {
        myGuest = guest;
        break;
      }
    }

    return Stack(
      children: [
        Scaffold(
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
                  if (_message != null) ...[
                    _SuccessBanner(message: _message!),
                    const SizedBox(height: 16),
                  ],
                  _SectionCard(
                    title: 'Profile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _EditableTextSetting(
                          label: 'Display name',
                          value: _nameController.text,
                          editing: _editingName,
                          controller: _nameController,
                          saving: _savingName,
                          onEdit: () => setState(() => _editingName = true),
                          onCancel: () {
                            ref
                                .read(authServiceProvider)
                                .getProfile()
                                .then((profile) {
                              if (!mounted) return;
                              _nameController.text = profile?.displayName ?? '';
                              setState(() => _editingName = false);
                            });
                          },
                          onSave: _saveDisplayName,
                        ),
                        if (email != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: AppFonts.sz(12),
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(email, style: TextStyle(fontSize: AppFonts.sz(15))),
                        ],
                        const SizedBox(height: 16),
                        _EditablePasswordSetting(
                            editing: _editingPassword,
                            formKey: _passwordFormKey,
                            newPasswordController: _newPasswordController,
                            confirmPasswordController: _confirmPasswordController,
                            obscureNewPassword: _obscureNewPassword,
                            obscureConfirmPassword: _obscureConfirmPassword,
                            saving: _savingPassword,
                            onEdit: () => setState(() => _editingPassword = true),
                            onCancel: () {
                              _newPasswordController.clear();
                              _confirmPasswordController.clear();
                              setState(() => _editingPassword = false);
                            },
                            onToggleNewPassword: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword,
                            ),
                            onToggleConfirmPassword: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                            onSave: _changePassword,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_household != null) ...[
                    _SectionCard(
                      title: 'Household',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HouseholdSelector(
                            memberships: _memberships,
                            selectedHouseholdId: _activeHouseholdId,
                            petsByHouseholdId: _petsByHouseholdId,
                            onSelect: _switchHousehold,
                          ),
                          const SizedBox(height: 16),
                          if (_isGuest) ...[
                            _HouseholdSubsection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Your access',
                                    style: AppFonts.nunito(
                                      fontSize: AppFonts.sz(14),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    myGuest == null
                                        ? 'Check-off access for this household'
                                        : formatGuestAccess(myGuest),
                                    style: TextStyle(fontSize: AppFonts.sz(15)),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_canManage) ...[
                            _EditableTextSetting(
                              label: 'Household name',
                              value: _householdNameController.text,
                              editing: _editingHouseholdName,
                              controller: _householdNameController,
                              saving: _savingHouseholdName,
                              onEdit: () =>
                                  setState(() => _editingHouseholdName = true),
                              onCancel: () {
                                _householdNameController.text =
                                    _household?.name ?? '';
                                setState(() => _editingHouseholdName = false);
                              },
                              onSave: _saveHouseholdName,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Invite code',
                              style: TextStyle(
                                fontSize: AppFonts.sz(12),
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.8),
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
                                style: AppFonts.nunito(
                                  fontSize: AppFonts.sz(22),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: _copyInviteCode,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Copy invite code'),
                            ),
                          ] else ...[
                            Text(
                              'Household name',
                              style: TextStyle(
                                fontSize: AppFonts.sz(12),
                                color: AppColors.textSecondary.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _household!.name,
                              style: TextStyle(fontSize: AppFonts.sz(15)),
                            ),
                          ],
                          if (!_isGuest) ...[
                            _HouseholdSubsection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Family members',
                                    style: AppFonts.nunito(
                                      fontSize: AppFonts.sz(14),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._members.map(
                                    (member) {
                                      if (_editingMemberId == member.userId) {
                                        return _MemberEditForm(
                                          member: member,
                                          role: _editMemberRole,
                                          saving: _savingMemberRole,
                                          onRoleChanged: (role) =>
                                              setState(() => _editMemberRole = role),
                                          onDone: _saveMemberRole,
                                          onCancel: _cancelEditMember,
                                        );
                                      }

                                      return _MemberRow(
                                        member: member,
                                        isYou: member.userId == myUserId,
                                        canEdit: _canEditMemberRole(
                                          member,
                                          myUserId,
                                        ),
                                        canRemove: member.userId != myUserId &&
                                            _canRemove(member.role),
                                        onEdit: () => _startEditMember(member),
                                        confirmRemove: () =>
                                            _confirmRemoveMemberSwipe(member),
                                        onRemoveConfirmed: () =>
                                            _removeMemberDirect(member),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (_canManage) ...[
                            _HouseholdSubsection(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Guests',
                                    style: AppFonts.nunito(
                                      fontSize: AppFonts.sz(14),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Give a pet sitter check-off access for specific dates. They need a TrackPepper account with this email.',
                                    style: TextStyle(
                                      fontSize: AppFonts.sz(13),
                                      height: 1.5,
                                      color: AppColors.textSecondary
                                          .withValues(alpha: 0.95),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ..._guests.map(
                                    (guest) {
                                      if (_editingGuestId == guest.userId) {
                                        return _GuestForm(
                                          guestName: guest.displayName,
                                          fromDate: _editGuestFromDate,
                                          untilDate: _editGuestUntilDate,
                                          guestDays: _editGuestDays,
                                          saving: _savingGuestAccess,
                                          submitLabel: 'Done',
                                          savingLabel: 'Saving…',
                                          onPickFrom: _pickEditGuestFromDate,
                                          onPickUntil: _pickEditGuestUntilDate,
                                          onToggleDay: (day, selected) {
                                            setState(() {
                                              if (selected) {
                                                _editGuestDays.add(day);
                                              } else {
                                                _editGuestDays.remove(day);
                                              }
                                            });
                                          },
                                          onCancel: _cancelEditGuest,
                                          onSubmit: _saveGuestAccess,
                                        );
                                      }

                                      return _GuestRow(
                                        guest: guest,
                                        onEdit: () => _startEditGuest(guest),
                                        confirmRemove: () =>
                                            _confirmRemoveMemberSwipe(guest),
                                        onRemoveConfirmed: () =>
                                            _removeMemberDirect(guest),
                                      );
                                    },
                                  ),
                                  if (_showGuestForm)
                                    _GuestForm(
                                      emailController: _guestEmailController,
                                      fromDate: _guestFromDate,
                                      untilDate: _guestUntilDate,
                                      guestDays: _guestDays,
                                      saving: _addingGuest,
                                      submitLabel: 'Add guest',
                                      savingLabel: 'Adding…',
                                      onPickFrom: _pickGuestFromDate,
                                      onPickUntil: _pickGuestUntilDate,
                                      onToggleDay: (day, selected) {
                                        setState(() {
                                          if (selected) {
                                            _guestDays.add(day);
                                          } else {
                                            _guestDays.remove(day);
                                          }
                                        });
                                      },
                                      onCancel: _cancelGuestForm,
                                      onSubmit: _addGuest,
                                    )
                                  else
                                    OutlinedButton(
                                      onPressed: () => setState(() {
                                        _cancelEditGuest();
                                        _showGuestForm = true;
                                      }),
                                      style: OutlinedButton.styleFrom(
                                        padding:
                                            const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('Add guest'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (!_isGuest && _activeHouseholdId != null)
                            _HouseholdSubsection(
                              child: PetsSection(
                                householdId: _activeHouseholdId!,
                                canManagePets: !_isGuest,
                                onMessage: (message) {
                                  setState(() => _message = message);
                                  _load();
                                },
                                onError: (message) {
                                  setState(() => _error = message);
                                },
                              ),
                            ),
                          if (_currentRole == HouseholdRole.owner)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                "As the owner, you can't leave this household.",
                                style: TextStyle(
                                  fontSize: AppFonts.sz(12.5),
                                  height: 1.5,
                                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                                ),
                              ),
                            )
                          else if (_currentRole != null &&
                              _currentRole != HouseholdRole.guest)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: OutlinedButton(
                                onPressed: _leaving ? null : _leaveHousehold,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                child: Text(
                                  _leaving ? 'Leaving…' : 'Leave household',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (recommendationsForPetSpeciesList(
                    _pets.map((pet) => pet.species),
                  ).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Our recommendations',
                      child: RecommendationsSection(
                        items: recommendationsForPetSpeciesList(
                          _pets.map((pet) => pet.species),
                        ),
                        title: '',
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
        ),
        ConfirmDialog(
          open: _showLeaveConfirm,
          title: 'Leave household?',
          message:
              "You will lose access to this household's pets and schedules.",
          confirmLabel: 'Leave household',
          confirmingLabel: 'Leaving…',
          confirming: _leaving,
          onCancel: () {
            if (!_leaving) setState(() => _showLeaveConfirm = false);
          },
          onConfirm: _confirmLeaveHousehold,
        ),
      ],
    );
  }
}

class _HouseholdSubsection extends StatelessWidget {
  const _HouseholdSubsection({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: const Color(0xFFC9A87C).withValues(alpha: 0.25),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 24),
          child: child,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.isYou,
    required this.canEdit,
    required this.canRemove,
    required this.onEdit,
    required this.confirmRemove,
    required this.onRemoveConfirmed,
  });

  final HouseholdMember member;
  final bool isYou;
  final bool canEdit;
  final bool canRemove;
  final VoidCallback onEdit;
  final Future<bool> Function() confirmRemove;
  final VoidCallback onRemoveConfirmed;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.sleepBg,
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.sleep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    member.displayName,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppFonts.sz(15),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _RoleBadge(label: member.role.label),
              ],
            ),
          ),
          if (canEdit)
            OutlinedButton(
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppColors.header,
                side: BorderSide(
                  color: AppColors.divider.withValues(alpha: 0.4),
                ),
                backgroundColor: Colors.white,
                textStyle: AppFonts.nunito(
                  fontSize: AppFonts.sz(12),
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Edit'),
            )
          else if (isYou)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pottyBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'You',
                style: TextStyle(
                  fontSize: AppFonts.sz(11),
                  fontWeight: FontWeight.w700,
                  color: AppColors.potty,
                ),
              ),
            ),
        ],
      ),
    );

    if (!canRemove) return row;

    return Dismissible(
      key: ValueKey(member.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.trainBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.train,
        ),
      ),
      confirmDismiss: (_) => confirmRemove(),
      onDismissed: (_) => onRemoveConfirmed(),
      child: row,
    );
  }
}

class _MemberEditForm extends StatelessWidget {
  const _MemberEditForm({
    required this.member,
    required this.role,
    required this.saving,
    required this.onRoleChanged,
    required this.onDone,
    required this.onCancel,
  });

  final HouseholdMember member;
  final HouseholdRole role;
  final bool saving;
  final ValueChanged<HouseholdRole> onRoleChanged;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.sleepBg,
                child: Text(
                  member.displayName.isNotEmpty
                      ? member.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.sleep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                member.displayName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: AppFonts.sz(15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Role',
            style: TextStyle(
              fontSize: AppFonts.sz(12),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => onRoleChanged(HouseholdRole.member),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: role == HouseholdRole.member
                        ? const Color(0xFFC9A87C).withValues(alpha: 0.2)
                        : Colors.white,
                    foregroundColor: AppColors.header,
                    side: BorderSide(
                      color: role == HouseholdRole.member
                          ? AppColors.header
                          : AppColors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text('Member'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: saving
                      ? null
                      : () => onRoleChanged(HouseholdRole.admin),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: role == HouseholdRole.admin
                        ? const Color(0xFFC9A87C).withValues(alpha: 0.2)
                        : Colors.white,
                    foregroundColor: AppColors.header,
                    side: BorderSide(
                      color: role == HouseholdRole.admin
                          ? AppColors.header
                          : AppColors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text('Admin'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : onDone,
                  child: Text(saving ? 'Saving…' : 'Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestRow extends StatelessWidget {
  const _GuestRow({
    required this.guest,
    required this.onEdit,
    required this.confirmRemove,
    required this.onRemoveConfirmed,
  });

  final HouseholdMember guest;
  final VoidCallback onEdit;
  final Future<bool> Function() confirmRemove;
  final VoidCallback onRemoveConfirmed;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.sleepBg,
            child: Text(
              guest.displayName.isNotEmpty
                  ? guest.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.sleep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppFonts.sz(15),
                  ),
                ),
                Text(
                  formatGuestAccess(guest),
                  style: TextStyle(
                    fontSize: AppFonts.sz(12),
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: AppColors.header,
              side: BorderSide(
                color: AppColors.divider.withValues(alpha: 0.4),
              ),
              backgroundColor: Colors.white,
              textStyle: AppFonts.nunito(
                fontSize: AppFonts.sz(12),
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey(guest.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.trainBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: AppColors.train,
        ),
      ),
      confirmDismiss: (_) => confirmRemove(),
      onDismissed: (_) => onRemoveConfirmed(),
      child: row,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFC9A87C).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: AppFonts.sz(11),
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class _GuestForm extends StatelessWidget {
  const _GuestForm({
    this.guestName,
    this.emailController,
    required this.fromDate,
    required this.untilDate,
    required this.guestDays,
    required this.saving,
    required this.submitLabel,
    required this.savingLabel,
    required this.onPickFrom,
    required this.onPickUntil,
    required this.onToggleDay,
    required this.onCancel,
    required this.onSubmit,
  });

  final String? guestName;
  final TextEditingController? emailController;
  final DateTime? fromDate;
  final DateTime? untilDate;
  final Set<int> guestDays;
  final bool saving;
  final String submitLabel;
  final String savingLabel;
  final VoidCallback onPickFrom;
  final VoidCallback onPickUntil;
  final void Function(int day, bool selected) onToggleDay;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        if (guestName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              guestName!,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppFonts.sz(15),
              ),
            ),
          ),
        if (emailController != null) ...[
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPickFrom,
                child: Text(
                  fromDate == null
                      ? 'From'
                      : 'From ${formatGuestAccessDate(fromDate!)}',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onPickUntil,
                child: Text(
                  untilDate == null
                      ? 'Until'
                      : 'Until ${formatGuestAccessDate(untilDate!)}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Days (optional)',
          style: TextStyle(
            fontSize: AppFonts.sz(13),
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final day in const [
              (0, 'Sun'),
              (1, 'Mon'),
              (2, 'Tue'),
              (3, 'Wed'),
              (4, 'Thu'),
              (5, 'Fri'),
              (6, 'Sat'),
            ])
              OutlinedButton(
                onPressed: () => onToggleDay(day.$1, !guestDays.contains(day.$1)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: guestDays.contains(day.$1)
                      ? const Color(0xFFFFFAF5)
                      : Colors.white,
                  foregroundColor: guestDays.contains(day.$1)
                      ? AppColors.header
                      : AppColors.textSecondary,
                  side: BorderSide(
                    color: guestDays.contains(day.$1)
                        ? AppColors.header
                        : const Color(0xFFC9A87C).withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(day.$2, style: TextStyle(fontSize: AppFonts.sz(12))),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: saving ? null : onSubmit,
                child: Text(saving ? savingLabel : submitLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditableTextSetting extends StatelessWidget {
  const _EditableTextSetting({
    required this.label,
    required this.value,
    required this.editing,
    required this.controller,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onSave,
  });

  final String label;
  final String value;
  final bool editing;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: AppFonts.sz(12),
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Edit $label',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.trim().isEmpty ? 'Not set' : value.trim(),
            style: TextStyle(fontSize: AppFonts.sz(15)),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EditablePasswordSetting extends StatelessWidget {
  const _EditablePasswordSetting({
    required this.editing,
    required this.formKey,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureNewPassword,
    required this.obscureConfirmPassword,
    required this.saving,
    required this.onEdit,
    required this.onCancel,
    required this.onToggleNewPassword,
    required this.onToggleConfirmPassword,
    required this.onSave,
  });

  final bool editing;
  final GlobalKey<FormState> formKey;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureNewPassword;
  final bool obscureConfirmPassword;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onCancel;
  final VoidCallback onToggleNewPassword;
  final VoidCallback onToggleConfirmPassword;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontSize: AppFonts.sz(12),
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Change password',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('••••••••', style: TextStyle(fontSize: AppFonts.sz(15))),
        ],
      );
    }

    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: newPasswordController,
              obscureText: obscureNewPassword,
              autofocus: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'New password',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureNewPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onToggleNewPassword,
                ),
              ),
              validator: (v) =>
                  v != null && v.length >= 6 ? null : 'Min 6 characters',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: confirmPasswordController,
              obscureText: obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: onToggleConfirmPassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Min 6 characters';
                }
                if (v != newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: saving ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: saving ? null : onSave,
                    child: saving
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
                ),
              ],
            ),
          ],
        ),
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
              style: AppFonts.nunito(
                fontSize: AppFonts.sz(14),
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
        style: TextStyle(
          color: AppColors.potty,
          fontSize: AppFonts.sz(13),
          fontWeight: FontWeight.w600,
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
        style: TextStyle(color: AppColors.train, fontSize: AppFonts.sz(13)),
      ),
    );
  }
}
