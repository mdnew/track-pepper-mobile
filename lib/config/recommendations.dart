import '../models/pet.dart';

enum RecommendationCategory { food, gear, care }

enum RecommendationSpecies { all, dog, cat }

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.description,
    required this.href,
    required this.species,
    required this.category,
  });

  final String id;
  final String title;
  final String description;
  final String href;
  final RecommendationSpecies species;
  final RecommendationCategory category;
}

const affiliateDisclosure =
    'Some links are Amazon affiliate links. We may earn a small commission at no extra cost to you.';

const recommendations = <Recommendation>[
  Recommendation(
    id: 'puppy-food',
    title: 'Puppy Food We Use',
    description:
        'The kibble Pepper eats for everyday meals. Always check with your vet for your puppy’s specific needs.',
    href: 'https://amzn.to/4wc4je3',
    species: RecommendationSpecies.dog,
    category: RecommendationCategory.food,
  ),
  Recommendation(
    id: 'nerf-fetch-ball',
    title: 'Nerf Dog Trackshot Ball',
    description:
        'The squeaky fetch ball Pepper loves: lightweight, durable, and easy to spot in the yard.',
    href: 'https://amzn.to/4akJsgf',
    species: RecommendationSpecies.dog,
    category: RecommendationCategory.gear,
  ),
  Recommendation(
    id: 'jasonwell-dog-pool',
    title: 'Jasonwell Foldable Dog Pool',
    description:
        'The 79" splash pool Pepper loves: folds flat for storage, no inflation needed, great for backyard cool-offs.',
    href: 'https://amzn.to/4f6TGn3',
    species: RecommendationSpecies.dog,
    category: RecommendationCategory.gear,
  ),
  Recommendation(
    id: 'bene-bac-probiotic',
    title: 'PetAg Bene-Bac Probiotic',
    description:
        'The probiotic powder we use to help keep Pepper regular, useful after diet changes, antibiotics, or travel.',
    href: 'https://amzn.to/4wc4LJh',
    species: RecommendationSpecies.dog,
    category: RecommendationCategory.care,
  ),
];

List<Recommendation> recommendationsForSpecies(PetSpecies? species) {
  if (species == null) return recommendations;

  return recommendations.where((item) {
    return item.species == RecommendationSpecies.all ||
        (item.species == RecommendationSpecies.dog &&
            species == PetSpecies.dog) ||
        (item.species == RecommendationSpecies.cat &&
            species == PetSpecies.cat);
  }).toList();
}

List<Recommendation> recommendationsForPetSpeciesList(
  Iterable<PetSpecies> speciesList,
) {
  final species = speciesList.toSet();
  if (species.isEmpty) return recommendations;

  return recommendations.where((item) {
    if (item.species == RecommendationSpecies.all) return true;
    if (item.species == RecommendationSpecies.dog) {
      return species.contains(PetSpecies.dog);
    }
    if (item.species == RecommendationSpecies.cat) {
      return species.contains(PetSpecies.cat);
    }
    return false;
  }).toList();
}

String categoryLabel(RecommendationCategory category) {
  switch (category) {
    case RecommendationCategory.food:
      return 'Food';
    case RecommendationCategory.gear:
      return 'Gear';
    case RecommendationCategory.care:
      return 'Care';
  }
}

String categoryIcon(RecommendationCategory category) {
  switch (category) {
    case RecommendationCategory.food:
      return '🍽️';
    case RecommendationCategory.gear:
      return '🎒';
    case RecommendationCategory.care:
      return '💚';
  }
}
