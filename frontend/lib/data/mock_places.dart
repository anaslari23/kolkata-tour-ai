import '../models/place.dart';

const mockPlaces = <Place>[
  Place(
    id: 'victoria',
    name: 'Victoria Memorial',
    category: 'Historical',
    description:
        'A large marble building dedicated to Queen Victoria, now a museum and top tourist destination in Kolkata.',
    images: [
      'https://images.unsplash.com/photo-1596909397531-1a8f359bd18b?q=80&w=1200&auto=format&fit=crop',
      'https://images.unsplash.com/photo-1600431521340-4911e0a881ff?q=80&w=1200&auto=format&fit=crop',
    ],
    tags: ['Photography', 'Popular'],
    lat: 22.5448,
    lng: 88.3426,
    distanceKm: 1.2,
  ),
  Place(
    id: 'howrah',
    name: 'Howrah Bridge',
    category: 'Landmark',
    description:
        'An iconic cantilever bridge over the Hooghly River, a symbol of the city.',
    images: [
      'https://images.unsplash.com/photo-1580564746810-1b64e633a2ba?q=80&w=1200&auto=format&fit=crop',
    ],
    tags: ['Photography'],
    lat: 22.5850,
    lng: 88.3468,
    distanceKm: 3.5,
  ),
  Place(
    id: 'dakshineswar',
    name: 'Dakshineswar Temple',
    category: 'Religious',
    description:
        'A famed 19th-century Hindu temple complex on the eastern bank of the Hooghly River.',
    images: [
      'https://images.unsplash.com/photo-1581594549595-066c1f3fef25?q=80&w=1200&auto=format&fit=crop',
    ],
    tags: ['Family-Friendly'],
    lat: 22.6547,
    lng: 88.3570,
    distanceKm: 7.8,
  ),
  Place(
    id: 'indian_coffee_house',
    name: 'Indian Coffee House',
    category: 'Food',
    description:
        'A vintage cafe famous for adda, nostalgia, and pocket-friendly fare on College Street.',
    images: [
      'https://images.unsplash.com/photo-1514933651103-005eec06c04b?q=80&w=1200&auto=format&fit=crop',
    ],
    tags: ['Hidden Gem'],
    lat: 22.5744,
    lng: 88.3639,
    distanceKm: 2.1,
  ),
];
