import 'package:shared_preferences/shared_preferences.dart';

class SwipeSettings {
  const SwipeSettings({
    this.sensitivity = 0.18,
    this.cooldownMs = 1500,
    this.upOnly = false,
  });

  final double sensitivity;
  final int cooldownMs;
  final bool upOnly;
}

class SettingsStore {
  static const sensitivityKey = 'sensitivity';
  static const cooldownKey = 'cooldownMs';
  static const upOnlyKey = 'upOnly';

  Future<SwipeSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SwipeSettings(
      sensitivity: _sensitivity(prefs.getDouble(sensitivityKey) ?? 0.18),
      cooldownMs: _cooldown(prefs.getInt(cooldownKey) ?? 1500),
      upOnly: prefs.getBool(upOnlyKey) ?? false,
    );
  }

  Future<void> save(SwipeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(sensitivityKey, _sensitivity(settings.sensitivity));
    await prefs.setInt(cooldownKey, _cooldown(settings.cooldownMs));
    await prefs.setBool(upOnlyKey, settings.upOnly);
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
