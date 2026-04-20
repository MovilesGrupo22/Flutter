import 'dart:convert';
import 'dart:io';

class WeatherContext {
  final String mood;
  final String label;
  final double? temperatureC;

  const WeatherContext({
    required this.mood,
    required this.label,
    required this.temperatureC,
  });
}

class WeatherService {
  WeatherService._();

  static final WeatherService instance = WeatherService._();

  Future<WeatherContext> fetchCampusWeather() async {
    const url =
        'https://api.open-meteo.com/v1/forecast?latitude=4.6017&longitude=-74.0662&current=temperature_2m,weather_code&timezone=auto';

    HttpClient? client;

    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return const WeatherContext(
          mood: 'neutral',
          label: 'Time-aware recommendations',
          temperatureC: null,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final temperature = (current['temperature_2m'] as num?)?.toDouble();
      final weatherCode = (current['weather_code'] as num?)?.toInt();

      final mood = _resolveMood(
        temperatureC: temperature,
        weatherCode: weatherCode,
      );

      return WeatherContext(
        mood: mood,
        label: _labelForMood(mood, temperature),
        temperatureC: temperature,
      );
    } catch (_) {
      return const WeatherContext(
        mood: 'neutral',
        label: 'Time-aware recommendations',
        temperatureC: null,
      );
    } finally {
      client?.close(force: true);
    }
  }

  String _resolveMood({
    required double? temperatureC,
    required int? weatherCode,
  }) {
    const rainyCodes = {
      51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99,
    };

    if (weatherCode != null && rainyCodes.contains(weatherCode)) {
      return 'rainy';
    }

    if (temperatureC != null && temperatureC <= 12) {
      return 'cold';
    }

    if (temperatureC != null && temperatureC >= 22) {
      return 'hot';
    }

    return 'neutral';
  }

  String _labelForMood(String mood, double? temperatureC) {
    final tempText = temperatureC != null ? ' • ${temperatureC.toStringAsFixed(0)}°C' : '';

    switch (mood) {
      case 'rainy':
        return 'Rainy weather$tempText';
      case 'cold':
        return 'Cold weather$tempText';
      case 'hot':
        return 'Warm weather$tempText';
      default:
        return 'Time-aware recommendations$tempText';
    }
  }
}
