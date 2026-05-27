# FoodAndes App

FoodAndes is a mobile application built with Flutter to help users discover restaurants around campus, review food options, save favorites, generate meal plans, and access useful recommendations from a single app.

The app combines restaurant discovery, user preferences, saved meal plans, reviews, maps, analytics, and offline-friendly behavior to improve the food decision experience for students and campus users.

---

## Main Features

### Restaurant Discovery

Users can browse available restaurants, check basic information, view ratings and reviews, search by name or category, and filter options according to their preferences.

### Restaurant Details

Each restaurant includes useful information such as category, rating, opening status, address, images, reviews, and map access when available.

### Favorites

Users can save restaurants as favorites and access them later from their profile or restaurant flows.

### Reviews

Users can read existing reviews and create their own reviews when the app has connectivity. Drafts and pending actions are handled to avoid losing user input.

### Meal Planner

The app can generate meal plan recommendations based on available restaurants and user preferences. Users can save their plans and access them later.

### Saved Meal Plan Export

Saved meal plans can be exported as local files in JSON or TXT format. This allows users to keep a copy of their plans even when they are offline.

### Smart Quick Picks

The app includes a quick recommendation view that suggests restaurant options based on the current available data.

### Recently Viewed Restaurants

The app keeps track of recently viewed restaurants so users can easily return to places they checked before.

### Map Integration

FoodAndes includes map support to help users locate restaurants and open navigation options when needed.

### Theme Options

Users can switch between light, dark, and system-based visual modes from the profile section.

---

## Offline and Connectivity Behavior

FoodAndes includes offline-friendly behavior for several parts of the app. When the device has no internet connection, the app avoids silent failures and shows clear messages to the user.

Some previously loaded or locally saved information can still be accessed offline, such as saved meal plans, recently viewed restaurants, search history, and cached restaurant information.

Actions that require external services, such as Google Sign-In, registration, password reset, map refreshes, and remote data synchronization, require an internet connection.

---

## Analytics and Business Questions

The app collects interaction and usage events that support analytics dashboards and business questions. These events can help analyze user behavior, restaurant demand, popular filters, section usage, and recommendation effectiveness.

---

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Analytics
- Google Maps
- Local storage
- Connectivity support
- Image caching

---

## Installation and Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd Flutter-main/foodandes_app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Make sure the Firebase configuration files are available for the project.

Common required files include:

```text
lib/firebase_options.dart
android/app/google-services.json
```

### 4. Configure Google Maps

Add a valid Google Maps API key in the Android configuration before using map features.

### 5. Run the app

```bash
flutter run
```

For a clean build:

```bash
flutter clean
flutter pub get
flutter run
```

---

## Recommended Testing

Before presenting or distributing the app, test the following on a real device:

- Login and registration with internet connection.
- Google Sign-In with internet connection.
- Offline behavior in login and protected actions.
- Restaurant browsing with and without connection.
- Favorites flow.
- Reviews flow.
- Meal planner generation and saved plans.
- Exporting saved meal plans.
- Quick Picks recommendations.
- Recently viewed restaurants.
- Map access with a valid API key.
- Light and dark mode behavior.

---

## Team

- Juan Miguel Manrique
- Sergio Perez
- Jorge Solorzano

---

## Notes

FoodAndes supports offline-friendly behavior for cached and locally saved information. Some features still require an internet connection because they depend on Firebase, Google services, Google Maps, or remote synchronization.

This project was developed for academic purposes.
