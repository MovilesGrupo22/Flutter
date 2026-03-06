import 'package:foodandes_app/models/restaurant.dart';

const List<Restaurant> dummyRestaurants = [
  Restaurant(
    id: '1',
    name: 'Randys Hamburguesas & Steaks',
    category: 'Americana',
    rating: 4.7,
    priceLevel: 2,
    isOpen: true,
    isFavorite: false,
    imageUrl:
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=1000&q=80',
    description:
        'A casual burger place with fast service, steaks, and classic American comfort food.',
    menuItems: [
      'Classic Burger - \$22',
      'Double Cheese Burger - \$28',
      'BBQ Fries - \$12',
      'Steak Sandwich - \$30',
    ],
  ),
  Restaurant(
    id: '2',
    name: 'Ajonjolí',
    category: 'Casero',
    rating: 4.5,
    priceLevel: 3,
    isOpen: true,
    isFavorite: true,
    imageUrl:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1000&q=80',
    description:
        'Homestyle meals with local ingredients and affordable lunch options.',
    menuItems: [
      'Daily Lunch Menu - \$18',
      'Soup of the Day - \$10',
      'Fresh Juice - \$8',
      'Chicken with Rice - \$20',
    ],
  ),
  Restaurant(
    id: '3',
    name: 'Green Toast',
    category: 'Healthy',
    rating: 4.8,
    priceLevel: 3,
    isOpen: false,
    isFavorite: true,
    imageUrl:
        'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1000&q=80',
    description:
        'Healthy brunch and toast options with fresh ingredients and vegetarian alternatives.',
    menuItems: [
      'Avocado Toast - \$19',
      'Egg Toast - \$17',
      'Greek Yogurt Bowl - \$18',
      'Lemon Sparkling Water - \$7',
    ],
  ),
];