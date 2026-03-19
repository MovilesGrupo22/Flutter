# 🍽️ FoodAndes App

FoodAndes is a mobile application developed with Flutter that allows users to explore restaurants, view detailed information, read and write reviews, manage favorites, search dynamically, and navigate using Google Maps integration.

---

## 🚀 Features

* 📍 **Interactive Map**

  * Displays restaurants using Google Maps
  * Custom markers for each location
  * Navigate to restaurant detail directly from the map

* 🧭 **Get Directions**

  * Opens Google Maps with real-time directions
  * Uses device location as origin
  * Supports walking navigation

* 🔍 **Search**

  * Real-time filtering of restaurants
  * Search by name, category, tags, or address

* ❤️ **Favorites**

  * Add/remove restaurants from favorites
  * Synced with Firebase

* 📝 **Reviews**

  * View reviews per restaurant
  * Create new reviews
  * Automatic rating updates

* 📱 **Responsive UI**

  * Clean and modern interface
  * Smooth navigation between screens

---

## 🛠️ Tech Stack

* **Flutter**
* **Dart**
* **Firebase**

  * Firestore
  * Authentication
* **Google Maps API**
* **google_maps_flutter**
* **url_launcher**

---

## 📦 Installation

1. Clone the repository:

```bash
git clone https://github.com/your-repo/foodandes-app.git
cd foodandes-app
```

2. Install dependencies:

```bash
flutter pub get
```

3. Configure Firebase:

```bash
flutterfire configure
```

4. Add your Google Maps API key:

In `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

5. Run the app:

```bash
flutter run
```

---

## 👥 Team

* Juan Miguel Manrique
* Sergio Perez
* Jorge Solorzano

---

## 📌 Notes

* The app requires an active internet connection.
* Google Maps features depend on proper API key configuration.
* Location services should be enabled on the device for navigation features.

---

## 📄 License

This project is for academic purposes.
