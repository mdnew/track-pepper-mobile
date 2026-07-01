class CategoryDefaults {
  const CategoryDefaults({
    required this.title,
    required this.icon,
    required this.section,
  });

  final String title;
  final String icon;
  final String section;
}

const taskCategories = [
  'potty',
  'feed',
  'sleep',
  'play',
  'train',
  'wind',
  'night',
  'groom',
  'vet',
  'enrich',
  'note',
];

const categoryDefaults = {
  'potty': CategoryDefaults(title: 'Potty break', icon: '🚽', section: 'Routine'),
  'feed': CategoryDefaults(title: 'Feed', icon: '🍽', section: 'Meals'),
  'sleep': CategoryDefaults(title: 'Nap', icon: '😴', section: 'Rest'),
  'play': CategoryDefaults(title: 'Play', icon: '🎾', section: 'Activity'),
  'train': CategoryDefaults(title: 'Training', icon: '🎓', section: 'Training'),
  'wind': CategoryDefaults(title: 'Wind down', icon: '🌙', section: 'Evening'),
  'night': CategoryDefaults(title: 'Bedtime', icon: '🛏', section: 'Night'),
  'groom': CategoryDefaults(title: 'Grooming', icon: '✂️', section: 'Care'),
  'vet': CategoryDefaults(title: 'Vet / meds', icon: '💊', section: 'Health'),
  'enrich': CategoryDefaults(title: 'Enrichment', icon: '🧩', section: 'Activity'),
  'note': CategoryDefaults(title: 'Note', icon: '📝', section: 'Notes'),
};

CategoryDefaults categoryDefaultsFor(String category) =>
    categoryDefaults[category] ?? categoryDefaults['note']!;
