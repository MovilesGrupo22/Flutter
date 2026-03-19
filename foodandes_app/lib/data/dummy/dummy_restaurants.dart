import 'package:foodandes_app/models/restaurant.dart';

const List<Restaurant> dummyRestaurants = [
  Restaurant(
    id: '1',
    name: 'Randys Hamburguesas & Steaks',
    category: 'Americana',
    description:
        'Especializada en comida rápida de estilo estadounidense, parrillada, hamburguesas al carbón y carnes.',
    imageURL:
        'https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=1000&q=80',
    isOpen: true,
    latitude: 4.6038,
    longitude: -74.0660,
    openingHours: '11:30 AM - 6:30 PM',
    priceRange: r'$$',
    rating: 4.7,
    reviewCount: 1,
    tags: ['Burgers', 'Fast Food', 'Grill'],
    address: 'Cra. 1 #20-45, Bogotá',
    phone: '6017441919',
    isFavorite: false,
  ),
  Restaurant(
    id: '2',
    name: 'Ajonjolí',
    category: 'Casero',
    description:
        'Homestyle food with local ingredients and affordable lunch menus.',
    imageURL:
        'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=1000&q=80',
    isOpen: true,
    latitude: 4.6041,
    longitude: -74.0658,
    openingHours: '12:00 PM - 5:00 PM',
    priceRange: r'$$$',
    rating: 4.5,
    reviewCount: 3,
    tags: ['Casero', 'Lunch', 'Traditional'],
    address: 'Cra. 1 Este #19A-40, Bogotá',
    phone: '6010000000',
    isFavorite: true,
  ),
  Restaurant(
    id: '3',
    name: 'Green Toast',
    category: 'Healthy',
    description:
        'Healthy meals, fresh ingredients, and vegetarian-friendly options.',
    imageURL:
        'https://images.unsplash.com/photo-1547592180-85f173990554?auto=format&fit=crop&w=1000&q=80',
    isOpen: false,
    latitude: 4.6045,
    longitude: -74.0655,
    openingHours: '8:00 AM - 4:00 PM',
    priceRange: r'$$$',
    rating: 4.8,
    reviewCount: 5,
    tags: ['Healthy', 'Vegetarian', 'Brunch'],
    address: 'Cl. 19A #1-37, Bogotá',
    phone: '6011111111',
    isFavorite: true,
  ),
];