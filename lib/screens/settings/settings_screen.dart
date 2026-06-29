import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/household.dart';
import '../../models/household_member.dart';
import '../../models/household_membership.dart';
import '../../models/household_role.dart';
import '../../models/pet.dart';
import '../../providers/providers.dart';
import '../../screens/schedule/schedule_editor_screen.dart';
import '../../utils/analytics.dart';
import '../../utils/pet_age.dart';
import '../../widgets/household_selector.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _householdNameController = TextEditingController();
  final _guestEmailController = TextEditingController();
  final _guestFromController = TextEditingController();
  final _guestUntilController = TextEditingController();
  final Set<int> _guestDays = {};
  final _petNameController = TextEditingController();
  DateTime? _petDob;
  PetSpecies _petSpecies = PetSpecies.dog;
  Household? _household;
  List<Pet> _pets = const [];
  List<HouseholdMember> _members = const [];
  List<HouseholdMember> _guests = const [];
  List<HouseholdMembership> _memberships = const [];
  Map<String, List<Pet>> _petsByHouseholdId = const {};
  String? _activeHouseholdId;
  HouseholdRole? _currentRole;
  bool _loading = true;
  bool _saving = false;

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
    _guestEmailController.dispose();
    _guestFromController.dispose();
    _guestUntilController.dispose();
    _petNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = ref.read(authServiceProvider);
    final profile = await auth.getProfile();
    final memberships = await auth.getMemberships();
    final activeHouseholdId = await ref.read(activeHouseholdIdProvider.future);
    if (activeHouseholdId == null) {
      setState(() => _loading = false);
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
    if (!mounted) return;
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
      _pets = petsByHousehold[activeHouseholdId] ?? const [];
      _loading = false;
    });
  }

  bool get _canManage => _currentRole == HouseholdRole.owner || _currentRole == HouseholdRole.admin;
  bool get _isGuest => _currentRole == HouseholdRole.guest;

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).updateDisplayName(name);
      ref.invalidate(profileProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Display name updated')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveHouseholdName() async {
    if (_activeHouseholdId == null) return;
    final name = _householdNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(authServiceProvider).updateHouseholdName(_activeHouseholdId!, name);
      ref.invalidate(householdProvider);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Household name updated')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _switchHousehold(String householdId) async {
    await ref.read(authServiceProvider).setActiveHousehold(householdId);
    ref.invalidate(activeHouseholdIdProvider);
    ref.invalidate(householdProvider);
    ref.invalidate(petsProvider);
    ref.invalidate(petsByHouseholdProvider);
    await _load();
  }

  Future<void> _pickPetDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _petDob ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _petDob = picked);
  }

  Future<void> _addPet() async {
    if (_activeHouseholdId == null || _petDob == null || _petNameController.text.trim().isEmpty) {
      return;
    }
    await ref.read(petsServiceProvider).createPet(
          householdId: _activeHouseholdId,
          name: _petNameController.text.trim(),
          dateOfBirth: _petDob!,
          species: _petSpecies,
        );
    _petNameController.clear();
    _petDob = null;
    _petSpecies = PetSpecies.dog;
    ref.invalidate(petsProvider);
    ref.invalidate(petsByHouseholdProvider);
    await _load();
  }

  Future<void> _removeMember(HouseholdMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.role == HouseholdRole.guest ? 'Remove guest?' : 'Remove member?'),
        content: Text(
          member.role == HouseholdRole.guest
              ? '${member.displayName} will lose guest access to this household.'
              : '${member.displayName} will be removed from this household.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || _activeHouseholdId == null) return;
    await ref.read(authServiceProvider).removeMember(_activeHouseholdId!, member.userId);
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

  Future<void> _leaveHousehold() async {
    if (_activeHouseholdId == null) return;
    if (_currentRole == HouseholdRole.owner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Owners can't leave a household they own.")),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave household?'),
        content: const Text(
          'You will lose access to this household\'s pets and schedules.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave household')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authServiceProvider).leaveHousehold(_activeHouseholdId!);
    ref.invalidate(profileProvider);
    ref.invalidate(activeHouseholdIdProvider);
    await _load();
  }

  Future<void> _addGuest() async {
    if (_activeHouseholdId == null) return;
    final email = _guestEmailController.text.trim();
    final from = _guestFromController.text.trim();
    final until = _guestUntilController.text.trim();
    if (email.isEmpty || from.isEmpty || until.isEmpty) return;
    await ref.read(authServiceProvider).addGuestByEmail(
          _activeHouseholdId!,
          email,
          from,
          until,
          _guestDays.isEmpty
              ? null
              : (() {
                  final days = _guestDays.toList();
                  days.sort();
                  return days;
                })(),
        );
    _guestEmailController.clear();
    _guestFromController.clear();
    _guestUntilController.clear();
    _guestDays.clear();
    await _load();
  }

  Future<void> _signOut() async {
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
                  _SectionCard(
                    title: 'Profile',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display name')),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _saving ? null : _saveName, child: const Text('Save display name')),
                        if (email != null) ...[
                          const SizedBox(height: 8),
                          Text('Email: $email'),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_household != null)
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
                          const SizedBox(height: 12),
                          if (_canManage) ...[
                            TextField(
                              controller: _householdNameController,
                              decoration: const InputDecoration(labelText: 'Household name'),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _saving ? null : _saveHouseholdName, child: const Text('Save household name')),
                            const SizedBox(height: 8),
                            Text('Invite code: ${_household!.inviteCode}'),
                          ] else if (!_isGuest) ...[
                            Text('Household name: ${_household!.name}'),
                          ],
                          if (_isGuest) ...[
                            const SizedBox(height: 8),
                            const Text('Your access'),
                            Text(myGuest == null ? 'Check-off access for this household' : _formatGuestAccess(myGuest)),
                          ],
                          if (!_isGuest) ...[
                            const SizedBox(height: 12),
                            Text('Family members (${_members.length})'),
                            const SizedBox(height: 8),
                            for (final member in _members)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text(member.displayName.isEmpty ? '?' : member.displayName[0].toUpperCase())),
                                title: Text(member.displayName),
                                subtitle: Text(member.role.label),
                                trailing: member.userId != myUserId && _canRemove(member.role)
                                    ? TextButton(
                                        onPressed: () => _removeMember(member),
                                        child: const Text('Remove'),
                                      )
                                    : member.userId == myUserId
                                        ? const Text('You')
                                        : null,
                              ),
                          ],
                          if (_canManage) ...[
                            const SizedBox(height: 12),
                            Text('Guests (${_guests.length})'),
                            const SizedBox(height: 8),
                            for (final guest in _guests)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(guest.displayName),
                                subtitle: Text(_formatGuestAccess(guest)),
                                trailing: TextButton(
                                  onPressed: () => _removeMember(guest),
                                  child: const Text('Remove'),
                                ),
                              ),
                            TextField(
                              controller: _guestEmailController,
                              decoration: const InputDecoration(labelText: 'Guest email'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _guestFromController,
                              decoration: const InputDecoration(labelText: 'From (YYYY-MM-DD)'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _guestUntilController,
                              decoration: const InputDecoration(labelText: 'Until (YYYY-MM-DD)'),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
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
                                  FilterChip(
                                    label: Text(day.$2),
                                    selected: _guestDays.contains(day.$1),
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _guestDays.add(day.$1);
                                        } else {
                                          _guestDays.remove(day.$1);
                                        }
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _addGuest,
                              child: const Text('Add guest'),
                            ),
                          ],
                          if (!_isGuest) ...[
                            const SizedBox(height: 12),
                            Text('Pets (${_pets.length})'),
                            const SizedBox(height: 8),
                            for (final pet in _pets)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(formatPetSummary(pet)),
                                subtitle: Text('Born ${formatDateOfBirth(pet.dateOfBirth)}'),
                                trailing: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        if (_activeHouseholdId == null) return;
                                        await Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ScheduleEditorScreen(
                                              pet: pet,
                                              householdId: _activeHouseholdId!,
                                            ),
                                          ),
                                        );
                                        await _load();
                                      },
                                      child: const Text('Schedule'),
                                    ),
                                    TextButton(
                                      onPressed: () async {
                                        await ref.read(petsServiceProvider).deletePet(pet.id);
                                        await _load();
                                      },
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              ),
                            SegmentedButton<PetSpecies>(
                              segments: const [
                                ButtonSegment(value: PetSpecies.dog, label: Text('🐶 Dog')),
                                ButtonSegment(value: PetSpecies.cat, label: Text('🐱 Cat')),
                              ],
                              selected: {_petSpecies},
                              onSelectionChanged: (selection) {
                                setState(() => _petSpecies = selection.first);
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _petNameController,
                              decoration: const InputDecoration(labelText: 'New pet name'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _pickPetDob,
                              child: Text(
                                _petDob == null
                                    ? 'Choose date of birth'
                                    : 'Born ${formatDateOfBirth(_petDob!)}',
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _addPet, child: const Text('Add pet')),
                          ],
                          if (_currentRole == HouseholdRole.owner)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text("As the owner, you can't leave this household."),
                            )
                          else if (_currentRole != HouseholdRole.guest)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                onPressed: _leaveHousehold,
                                child: const Text('Leave household'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

String _formatGuestAccess(HouseholdMember member) {
  final parts = <String>[];
  if (member.validFrom != null) {
    parts.add(formatDateOfBirth(member.validFrom!));
  }
  if (member.validUntil != null) {
    parts.add(formatDateOfBirth(member.validUntil!));
  }
  final range = parts.length == 2
      ? '${parts[0]} - ${parts[1]}'
      : parts.length == 1
          ? 'From ${parts[0]}'
          : 'Any date';
  if (member.validDaysOfWeek == null || member.validDaysOfWeek!.isEmpty) {
    return range;
  }
  const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  final days = member.validDaysOfWeek!.map((day) => labels[day]).join(', ');
  return '$range · $days';
}
