final _persistedCustomTaskIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// True when [id] is a UUID stored in pet_schedule_tasks (not a plan template id).
bool isPersistedCustomTaskId(String id) {
  return _persistedCustomTaskIdPattern.hasMatch(id);
}
