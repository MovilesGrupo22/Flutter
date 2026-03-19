import 'package:flutter/material.dart';
import 'package:foodandes_app/features/auth/login_screen.dart';
import 'package:foodandes_app/features/auth/register_screen.dart';
import 'package:foodandes_app/features/favorites/favorites_empty_screen.dart';
import 'package:foodandes_app/features/home/home_filtered_screen.dart';
import 'package:foodandes_app/features/home/home_screen.dart';
import 'package:foodandes_app/features/map/map_screen.dart';
import 'package:foodandes_app/features/profile/profile_screen.dart';
import 'package:foodandes_app/features/restaurant/restaurant_detail_screen.dart';
import 'package:foodandes_app/features/search/search_active_screen.dart';
import 'package:foodandes_app/features/search/search_empty_screen.dart';
import 'package:foodandes_app/features/favorites/favorites_screen.dart';
import 'package:foodandes_app/features/restaurant/reviews_screen.dart';
import 'package:foodandes_app/features/restaurant/write_review_screen.dart';

class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        HomeFilteredScreen.routeName: (_) => const HomeFilteredScreen(),
        RestaurantDetailScreen.routeName: (_) => const RestaurantDetailScreen(),
        SearchEmptyScreen.routeName: (_) => const SearchEmptyScreen(),
        SearchActiveScreen.routeName: (_) => const SearchActiveScreen(),
        MapScreen.routeName: (_) => const MapScreen(),
        FavoritesEmptyScreen.routeName: (_) => const FavoritesEmptyScreen(),
        FavoritesScreen.routeName: (_) => const FavoritesScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        ReviewsScreen.routeName: (_) => const ReviewsScreen(),
        WriteReviewScreen.routeName: (_) => const WriteReviewScreen(),
      };
}