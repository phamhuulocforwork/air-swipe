import 'package:air_swipe/data/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults when nothing is stored', () async {
    final settings = await SettingsStore().load();
    expect(settings.sensitivity, 0.18);
    expect(settings.cooldownMs, 1500);
  });

  test('saves and reloads slider values', () async {
    final store = SettingsStore();
    await store.save(const SwipeSettings(sensitivity: 0.25, cooldownMs: 2000));
    final settings = await store.load();
    expect(settings.sensitivity, 0.25);
    expect(settings.cooldownMs, 2000);
  });

  test('clamps values into the slider range', () async {
    SharedPreferences.setMockInitialValues({
      SettingsStore.sensitivityKey: 0.9,
      SettingsStore.cooldownKey: 100,
    });
    final settings = await SettingsStore().load();
    expect(settings.sensitivity, 0.40);
    expect(settings.cooldownMs, 800);
  });
}
