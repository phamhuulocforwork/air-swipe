import 'package:shared_preferences/shared_preferences.dart';

class SwipeSettings {
  const SwipeSettings({this.sensitivity = 0.18, this.cooldownMs = 1500});

  final double sensitivity;
  final int cooldownMs;
}

class SettingsStore {
  static const sensitivityKey = 'sensitivity';
  static const cooldownKey = 'cooldownMs';

  Future<SwipeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SwipeSettings(
      sensitivity: _sensitivity(prefs.getDouble(sensitivityKey) ?? 0.18),
      cooldownMs: _cooldown(prefs.getInt(cooldownKey) ?? 1500),
    );
  }

  Future<void> save(SwipeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(sensitivityKey, _sensitivity(settings.sensitivity));
    await prefs.setInt(cooldownKey, _cooldown(settings.cooldownMs));
  }

  double _sensitivity(double value) {
    final clamped = value.clamp(0.08, 0.40);
    return (clamped * 100).round() / 100;
  }

  int _cooldown(int value) {
    final clamped = value.clamp(800, 3000);
    return (clamped / 100).round() * 100;
  }
}
