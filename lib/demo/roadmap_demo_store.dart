import '../data/schedule_seed.dart';
import '../models/completion.dart';
import '../models/household.dart';
import '../models/household_member.dart';
import '../models/household_membership.dart';
import '../models/household_role.dart';
import '../models/pet.dart';
import '../models/pet_schedule_meta.dart';
import '../models/profile.dart';
import '../models/schedule_plan.dart';
import '../models/schedule_task.dart';
import '../utils/schedule_plan.dart';

const demoUserId = 'demo-user-001';
const demoUserEmail = 'demo@trackpepper.test';

const _hhHome = 'demo-hh-home';
const _hhApt = 'demo-hh-apt';
const _hhSitter = 'demo-hh-sitter';
const _hhOak = 'demo-hh-oak';

const _petPepper = 'demo-pet-pepper';
const _petMochi = 'demo-pet-mochi';
const _petWhiskers = 'demo-pet-whiskers';
const _petBuddy = 'demo-pet-buddy';
const _petLuna = 'demo-pet-luna';

class RoadmapDemoStore {
  RoadmapDemoStore._() {
    _seedCompletions();
  }

  static final RoadmapDemoStore instance = RoadmapDemoStore._();

  final Map<String, Household> _households = {
    _hhHome: const Household(
      id: _hhHome,
      name: "Pepper's House",
      inviteCode: 'PEPPER-DEMO',
    ),
    _hhApt: const Household(
      id: _hhApt,
      name: "Grandma's Apartment",
      inviteCode: 'PEPPER-GRND',
    ),
    _hhSitter: const Household(
      id: _hhSitter,
      name: 'The Chen Family',
      inviteCode: 'PEPPER-SIT',
    ),
    _hhOak: const Household(
      id: _hhOak,
      name: 'Oak Street Home',
      inviteCode: 'PEPPER-OAK',
    ),
  };

  Profile _profile = const Profile(
    id: demoUserId,
    displayName: 'Demo User',
    householdId: _hhHome,
    activeHouseholdId: _hhHome,
  );

  String _activeHouseholdId = _hhHome;

  late final List<HouseholdMembership> _memberships = [
    HouseholdMembership(household: _households[_hhHome]!, role: HouseholdRole.owner),
    HouseholdMembership(household: _households[_hhApt]!, role: HouseholdRole.member),
    HouseholdMembership(household: _households[_hhOak]!, role: HouseholdRole.admin),
    HouseholdMembership(household: _households[_hhSitter]!, role: HouseholdRole.guest),
  ];

  late final Map<String, List<HouseholdMember>> _membersByHousehold = {
    _hhHome: [
      _member(
        userId: demoUserId,
        householdId: _hhHome,
        role: HouseholdRole.owner,
        displayName: 'Demo User',
        joinedAt: _daysAgo(120),
      ),
      _member(
        userId: 'demo-user-alex',
        householdId: _hhHome,
        role: HouseholdRole.admin,
        displayName: 'Alex',
        joinedAt: _daysAgo(90),
      ),
      _member(
        userId: 'demo-user-sam',
        householdId: _hhHome,
        role: HouseholdRole.member,
        displayName: 'Sam',
        joinedAt: _daysAgo(60),
      ),
    ],
    _hhApt: [
      _member(
        userId: demoUserId,
        householdId: _hhApt,
        role: HouseholdRole.member,
        displayName: 'Demo User',
        joinedAt: _daysAgo(30),
      ),
      _member(
        userId: 'demo-user-grandma',
        householdId: _hhApt,
        role: HouseholdRole.owner,
        displayName: 'Grandma',
        joinedAt: _daysAgo(365),
      ),
    ],
    _hhSitter: [
      _member(
        userId: 'demo-user-chen',
        householdId: _hhSitter,
        role: HouseholdRole.owner,
        displayName: 'Michelle Chen',
        joinedAt: _daysAgo(400),
      ),
      _member(
        userId: 'demo-user-chen-partner',
        householdId: _hhSitter,
        role: HouseholdRole.member,
        displayName: 'David Chen',
        joinedAt: _daysAgo(400),
      ),
    ],
    _hhOak: [
      _member(
        userId: 'demo-user-maria',
        householdId: _hhOak,
        role: HouseholdRole.owner,
        displayName: 'Maria Rivera',
        joinedAt: _daysAgo(200),
      ),
      _member(
        userId: demoUserId,
        householdId: _hhOak,
        role: HouseholdRole.admin,
        displayName: 'Demo User',
        joinedAt: _daysAgo(45),
      ),
      _member(
        userId: 'demo-user-carlos',
        householdId: _hhOak,
        role: HouseholdRole.member,
        displayName: 'Carlos',
        joinedAt: _daysAgo(40),
      ),
    ],
  };

  late final Map<String, List<HouseholdMember>> _guestsByHousehold = {
    _hhHome: [
      _member(
        userId: 'demo-user-jordan',
        householdId: _hhHome,
        role: HouseholdRole.guest,
        displayName: 'Jordan (sitter)',
        joinedAt: _daysAgo(7),
        validFrom: _daysAgo(2),
        validUntil: _daysAgo(-5),
        validDaysOfWeek: const [5, 6],
      ),
    ],
    _hhApt: [],
    _hhOak: [],
    _hhSitter: [
      _member(
        userId: demoUserId,
        householdId: _hhSitter,
        role: HouseholdRole.guest,
        displayName: 'Demo User',
        joinedAt: _daysAgo(1),
        validFrom: _daysAgo(1),
        validUntil: _daysAgo(-6),
      ),
    ],
  };

  List<Pet> _pets = [
    Pet(
      id: _petPepper,
      householdId: _hhHome,
      name: 'Pepper',
      dateOfBirth: _daysAgo(70),
      species: PetSpecies.dog,
    ),
    Pet(
      id: _petMochi,
      householdId: _hhHome,
      name: 'Mochi',
      dateOfBirth: _daysAgo(56),
      species: PetSpecies.cat,
    ),
    Pet(
      id: _petWhiskers,
      householdId: _hhApt,
      name: 'Whiskers',
      dateOfBirth: _daysAgo(800),
      species: PetSpecies.cat,
    ),
    Pet(
      id: _petBuddy,
      householdId: _hhSitter,
      name: 'Buddy',
      dateOfBirth: _daysAgo(65),
      species: PetSpecies.dog,
    ),
    Pet(
      id: _petLuna,
      householdId: _hhOak,
      name: 'Luna',
      dateOfBirth: _daysAgo(120),
      species: PetSpecies.dog,
    ),
  ];

  final Map<String, PetScheduleMeta> _customScheduleMeta = {};
  final Map<String, List<ScheduleTask>> _customTasksByPet = {};
  List<Completion> _completions = [];

  Profile getProfile() => Profile(
        id: _profile.id,
        displayName: _profile.displayName,
        householdId: _profile.householdId,
        activeHouseholdId: _activeHouseholdId,
      );

  List<HouseholdMembership> getMemberships() => _memberships
      .map(
        (item) => HouseholdMembership(
          household: Household(
            id: item.household.id,
            name: item.household.name,
            inviteCode: item.household.inviteCode,
          ),
          role: item.role,
        ),
      )
      .toList();

  String getActiveHouseholdId() => _activeHouseholdId;

  void setActiveHousehold(String householdId) {
    _activeHouseholdId = householdId;
    _profile = Profile(
      id: _profile.id,
      displayName: _profile.displayName,
      householdId: _profile.householdId,
      activeHouseholdId: householdId,
    );
  }

  void updateDisplayName(String displayName) {
    final trimmed = displayName.trim();
    _profile = Profile(
      id: _profile.id,
      displayName: trimmed,
      householdId: _profile.householdId,
      activeHouseholdId: _profile.activeHouseholdId,
    );
    for (final members in _membersByHousehold.values) {
      final index = members.indexWhere((member) => member.userId == demoUserId);
      if (index >= 0) {
        final current = members[index];
        members[index] = HouseholdMember(
          userId: current.userId,
          householdId: current.householdId,
          role: current.role,
          displayName: trimmed,
          joinedAt: current.joinedAt,
          validFrom: current.validFrom,
          validUntil: current.validUntil,
          validDaysOfWeek: current.validDaysOfWeek,
        );
      }
    }
  }

  Household? getHousehold(String householdId) => _households[householdId];

  void updateHouseholdName(String householdId, String name) {
    final current = _households[householdId];
    if (current == null) return;
    _households[householdId] = Household(
      id: current.id,
      name: name.trim(),
      inviteCode: current.inviteCode,
    );
    final membershipIndex =
        _memberships.indexWhere((item) => item.household.id == householdId);
    if (membershipIndex >= 0) {
      _memberships[membershipIndex] = HouseholdMembership(
        household: _households[householdId]!,
        role: _memberships[membershipIndex].role,
      );
    }
  }

  List<HouseholdMember> getHouseholdMembers(String householdId) =>
      List<HouseholdMember>.from(_membersByHousehold[householdId] ?? const []);

  List<HouseholdMember> getGuestMembers(String householdId) =>
      List<HouseholdMember>.from(_guestsByHousehold[householdId] ?? const []);

  HouseholdRole? getCurrentRole(String householdId) {
    for (final membership in _memberships) {
      if (membership.household.id == householdId) return membership.role;
    }
    return null;
  }

  void removeMember(String householdId, String userId) {
    _membersByHousehold[householdId] = (_membersByHousehold[householdId] ?? [])
        .where((member) => member.userId != userId)
        .toList();
    _guestsByHousehold[householdId] = (_guestsByHousehold[householdId] ?? [])
        .where((member) => member.userId != userId)
        .toList();
  }

  void leaveHousehold(String householdId) {
    final membership = _memberships
        .where((item) => item.household.id == householdId)
        .cast<HouseholdMembership?>()
        .firstWhere((_) => true, orElse: () => null);
    if (membership?.role == HouseholdRole.owner) {
      throw Exception("Owners can't leave a household they own.");
    }
    _memberships.removeWhere((item) => item.household.id == householdId);
    _membersByHousehold[householdId] = (_membersByHousehold[householdId] ?? [])
        .where((member) => member.userId != demoUserId)
        .toList();
    _guestsByHousehold[householdId] = (_guestsByHousehold[householdId] ?? [])
        .where((member) => member.userId != demoUserId)
        .toList();
    if (_activeHouseholdId == householdId) {
      _activeHouseholdId = _memberships.isEmpty ? '' : _memberships.first.household.id;
      final household = _memberships.isEmpty ? null : _memberships.first.household.id;
      _profile = Profile(
        id: _profile.id,
        displayName: _profile.displayName,
        householdId: household,
        activeHouseholdId: _activeHouseholdId.isEmpty ? null : _activeHouseholdId,
      );
    }
  }

  void addGuestByEmail(
    String householdId,
    String email,
    String validFrom,
    String validUntil,
    List<int>? validDays,
  ) {
    final parts = email.split('@');
    final seed = parts.isEmpty ? 'Guest' : parts.first;
    final displayName =
        '${seed.substring(0, 1).toUpperCase()}${seed.substring(1)}';
    _guestsByHousehold[householdId] = [
      ...(_guestsByHousehold[householdId] ?? const []),
      HouseholdMember(
        userId: 'demo-guest-${DateTime.now().millisecondsSinceEpoch}',
        householdId: householdId,
        role: HouseholdRole.guest,
        displayName: displayName,
        joinedAt: DateTime.now(),
        validFrom: DateTime.parse('${validFrom}T00:00:00'),
        validUntil: DateTime.parse('${validUntil}T00:00:00'),
        validDaysOfWeek: validDays,
      ),
    ];
  }

  List<Pet> getPets(String householdId) =>
      _pets.where((pet) => pet.householdId == householdId).toList();

  Pet createPet(
    String householdId,
    String name,
    String dateOfBirth,
    PetSpecies species,
  ) {
    final pet = Pet(
      id: 'demo-pet-${DateTime.now().millisecondsSinceEpoch}',
      householdId: householdId,
      name: name.trim(),
      dateOfBirth: DateTime.parse('${dateOfBirth}T00:00:00'),
      species: species,
    );
    _pets = [..._pets, pet];
    return pet;
  }

  void updatePet(
    String id,
    String name,
    String dateOfBirth,
    PetSpecies species,
  ) {
    _pets = _pets
        .map(
          (pet) => pet.id == id
              ? Pet(
                  id: pet.id,
                  householdId: pet.householdId,
                  name: name.trim(),
                  dateOfBirth: DateTime.parse('${dateOfBirth}T00:00:00'),
                  species: species,
                )
              : pet,
        )
        .toList();
  }

  void deletePet(String id) {
    _pets = _pets.where((pet) => pet.id != id).toList();
    _customScheduleMeta.remove(id);
    _customTasksByPet.remove(id);
    _completions = _completions.where((completion) => completion.petId != id).toList();
  }

  List<SchedulePlan> getPlans() => scheduleSeedPlans;

  List<ScheduleTask> getTasksForPlan(String planId) =>
      scheduleSeedPlanTasks[planId] ?? const [];

  PetScheduleMeta? getPetScheduleMeta(String petId) => _customScheduleMeta[petId];

  List<ScheduleTask> getCustomTasksForPet(String petId) =>
      List<ScheduleTask>.from(_customTasksByPet[petId] ?? const []);

  ({SchedulePlan? plan, List<ScheduleTask> tasks}) getScheduleForPet(
    Pet pet,
    DateTime referenceDate,
  ) {
    final plan = resolvePlanForPet(scheduleSeedPlans, pet, referenceDate);
    final meta = _customScheduleMeta[pet.id];
    if (meta?.isCustomized == true) {
      return (plan: plan, tasks: List<ScheduleTask>.from(_customTasksByPet[pet.id] ?? const []));
    }
    if (plan == null) return (plan: null, tasks: const []);
    return (plan: plan, tasks: List<ScheduleTask>.from(scheduleSeedPlanTasks[plan.id] ?? const []));
  }

  List<Completion> getCompletionsForDate(
    String householdId,
    String petId,
    DateTime date,
  ) {
    final key = _dateKey(date);
    return _completions
        .where(
          (completion) =>
              completion.householdId == householdId &&
              completion.petId == petId &&
              _dateKey(completion.date) == key,
        )
        .toList();
  }

  ({Map<String, int> completions, Map<String, int> totals}) getAggregatedCountsForMonth(
    String householdId,
    List<Pet> householdPets,
    DateTime month,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);
    final completionMap = <String, int>{};
    final totalMap = <String, int>{};

    for (final completion in _completions) {
      if (completion.householdId != householdId) continue;
      final key = _dateKey(completion.date);
      final rowDate = DateTime.parse('${key}T00:00:00');
      if (rowDate.isBefore(start) || rowDate.isAfter(end)) continue;
      completionMap[key] = (completionMap[key] ?? 0) + 1;
    }

    var cursor = start;
    while (!cursor.isAfter(end)) {
      final key = _dateKey(cursor);
      var total = 0;
      for (final pet in householdPets) {
        total += getScheduleForPet(pet, cursor).tasks.length;
      }
      totalMap[key] = total;
      cursor = cursor.add(const Duration(days: 1));
    }

    return (completions: completionMap, totals: totalMap);
  }

  void completeTask(
    String householdId,
    String petId,
    String taskId,
    DateTime date,
    String userId,
  ) {
    final key = _dateKey(date);
    _completions = _completions
        .where(
          (completion) =>
              !(completion.petId == petId &&
                  completion.taskId == taskId &&
                  _dateKey(completion.date) == key),
        )
        .toList();
    Pet? pet;
    for (final row in _pets) {
      if (row.id == petId) {
        pet = row;
        break;
      }
    }
    if (pet == null) return;
    _completions = [..._completions, _makeCompletion(pet, taskId, date, userId)];
    if (householdId.isEmpty) return;
  }

  void uncompleteTask(
    String householdId,
    String petId,
    String taskId,
    DateTime date,
  ) {
    final key = _dateKey(date);
    _completions = _completions
        .where(
          (completion) =>
              !(completion.householdId == householdId &&
                  completion.petId == petId &&
                  completion.taskId == taskId &&
                  _dateKey(completion.date) == key),
        )
        .toList();
  }

  void completeAllTasks(
    String householdId,
    String petId,
    List<String> taskIds,
    DateTime date,
    String userId,
  ) {
    for (final taskId in taskIds) {
      completeTask(householdId, petId, taskId, date, userId);
    }
  }

  void saveCustomSchedule(
    String petId,
    String? basePlanId,
    List<ScheduleTask> tasks,
    String userId,
  ) {
    _customScheduleMeta[petId] = PetScheduleMeta(
      petId: petId,
      basePlanId: basePlanId,
      isCustomized: true,
    );
    _customTasksByPet[petId] = tasks
        .asMap()
        .entries
        .map(
          (entry) => ScheduleTask(
            id: entry.value.id.startsWith('new-')
                ? 'demo-custom-$petId-${entry.key}'
                : entry.value.id,
            planId: null,
            petId: petId,
            sortOrder: entry.key,
            timeLabel: entry.value.timeLabel,
            category: entry.value.category,
            title: entry.value.title,
            subtitle: entry.value.subtitle,
            icon: entry.value.icon,
            section: entry.value.section,
            isCustom: true,
          ),
        )
        .toList();
    if (userId.isEmpty) return;
  }

  void resetScheduleToDefault(String petId) {
    _customScheduleMeta.remove(petId);
    _customTasksByPet.remove(petId);
  }

  void _seedCompletions() {
    _completions = [];
    final today = _truncate(DateTime.now());
    for (final pet in _pets.where((row) => row.householdId == _hhHome)) {
      final plan = resolvePlanForPet(scheduleSeedPlans, pet, today);
      final tasks = plan == null ? <ScheduleTask>[] : (scheduleSeedPlanTasks[plan.id] ?? []);
      final completeCount = (tasks.length * 0.6).floor();
      for (var i = 0; i < completeCount; i++) {
        final task = tasks[i];
        _completions = [..._completions, _makeCompletion(pet, task.id, today, demoUserId)];
      }
      for (var dayOffset = 1; dayOffset <= 10; dayOffset++) {
        final day = today.subtract(Duration(days: dayOffset));
        final dayTasks = plan == null ? <ScheduleTask>[] : (scheduleSeedPlanTasks[plan.id] ?? []);
        final count = (dayTasks.length - (dayOffset % 3)).clamp(1, dayTasks.length);
        for (var i = 0; i < count; i++) {
          final task = dayTasks[i];
          _completions = [..._completions, _makeCompletion(pet, task.id, day, demoUserId)];
        }
      }
    }
  }

  Completion _makeCompletion(Pet pet, String taskId, DateTime date, String userId) {
    return Completion(
      id: 'demo-completion-${pet.id}-$taskId-${_dateKey(date)}',
      householdId: pet.householdId,
      petId: pet.id,
      taskId: taskId,
      date: _truncate(date),
      completedBy: userId,
      completedAt: _truncate(date).add(const Duration(hours: 1)),
      completedByName: userId == demoUserId ? 'Demo User' : 'Alex',
    );
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

HouseholdMember _member({
  required String userId,
  required String householdId,
  required HouseholdRole role,
  required String displayName,
  required DateTime joinedAt,
  DateTime? validFrom,
  DateTime? validUntil,
  List<int>? validDaysOfWeek,
}) {
  return HouseholdMember(
    userId: userId,
    householdId: householdId,
    role: role,
    displayName: displayName,
    joinedAt: joinedAt,
    validFrom: validFrom,
    validUntil: validUntil,
    validDaysOfWeek: validDaysOfWeek,
  );
}

DateTime _daysAgo(int days) => _truncate(DateTime.now()).subtract(Duration(days: days));

DateTime _truncate(DateTime date) => DateTime(date.year, date.month, date.day);
