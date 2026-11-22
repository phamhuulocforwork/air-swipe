import 'package:air_swipe/data/settings_store.dart';
import 'package:air_swipe/data/swipe_platform.dart';
import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';
import 'package:air_swipe/session/pose_session.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> with WidgetsBindingObserver {
  final SwipePlatform _platform = SwipePlatform();
  final SettingsStore _store = SettingsStore();
  late final PoseSession _session;

  var _accessibilityOn = false;
  var _canAddTile = false;
  var _sensitivity = 0.18;
  var _cooldownMs = 1500;
  var _toggleBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = PoseSession(platform: _platform);
    _session.onUpdate = () {
      if (mounted) {
        setState(() {});
      }
    };
    _platform.listenCommands(
      onStart: () => _setListening(true, collapse: true),
      onStop: () => _setListening(false, collapse: false),
      onCameraError: (message) async {
        _session.error = message;
        if (_session.listening || _session.starting) {
          await _session.stop();
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
    _boot();
  }

  Future<void> _boot() async {
    final settings = await _store.load();
    final canAddTile = await _platform.canRequestAddTile();
    final command = await _platform.takeCommand();
    if (!mounted) {
      return;
    }
    setState(() {
      _sensitivity = settings.sensitivity;
      _cooldownMs = settings.cooldownMs;
      _canAddTile = canAddTile;
    });
    _applyTrackerSettings();
    await _refreshAccessibility();
    if (command == 'start') {
      await _setListening(true, collapse: true);
    } else if (command == 'stop') {
      await _setListening(false, collapse: false);
    }
  }

  void _applyTrackerSettings() {
    _session.tracker.sensitivity = _sensitivity;
    _session.tracker.cooldown = Duration(milliseconds: _cooldownMs);
  }

  Future<void> _refreshAccessibility() async {
    final enabled = await _platform.isServiceEnabled();
    if (mounted) {
      setState(() => _accessibilityOn = enabled);
    }
  }

  Future<void> _saveSettings() {
    return _store.save(
      SwipeSettings(sensitivity: _sensitivity, cooldownMs: _cooldownMs),
    );
  }

  Future<void> _setListening(bool enabled, {required bool collapse}) async {
    if (_toggleBusy) {
      return;
    }
    _toggleBusy = true;
    if (mounted) {
      setState(() {});
    }
    try {
      if (enabled) {
        final camera = await Permission.camera.request();
        if (!camera.isGranted) {
          _session.error = 'Chưa cấp quyền camera';
          return;
        }
        await Permission.notification.request();
        _applyTrackerSettings();
        await _session.start(collapseAfter: collapse);
      } else {
        await _session.stop();
      }
    } finally {
      _toggleBusy = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _platform.setPreviewActive(true);
      _refreshAccessibility();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _platform.setPreviewActive(false);
    } else if (state == AppLifecycleState.detached) {
      _session.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gesture = switch (_session.lastGesture) {
      SwipeDirection.up => 'lên',
      SwipeDirection.down => 'xuống',
      null => '—',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('AirSwipe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bật AirSwipe'),
            value: _session.listening || _session.starting,
            onChanged: _toggleBusy
                ? null
                : (value) => _setListening(value, collapse: false),
          ),
          Text('Accessibility: ${_accessibilityOn ? 'Bật' : 'Tắt'}'),
          Text('Camera: ${_session.listening ? 'Bật' : 'Tắt'}'),
          Text('Cử chỉ gần nhất: $gesture'),
          Text('Lỗi: ${_session.error ?? '—'}'),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: _session.listening
                ? const AndroidView(viewType: 'com.airswipe/preview')
                : const ColoredBox(
                    color: Color(0xFFE0E0E0),
                    child: Center(child: Text('Camera tắt')),
                  ),
          ),
          const SizedBox(height: 12),
          Text('Độ nhạy ${_sensitivity.toStringAsFixed(2)}'),
          Slider(
            min: 0.08,
            max: 0.40,
            value: _sensitivity,
            onChanged: (value) {
              setState(() => _sensitivity = _snapSensitivity(value));
              _applyTrackerSettings();
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          Text('Cooldown $_cooldownMs ms'),
          Slider(
            min: 800,
            max: 3000,
            value: _cooldownMs.toDouble(),
            onChanged: (value) {
              setState(() => _cooldownMs = _snapCooldown(value));
              _applyTrackerSettings();
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await _platform.openAccessibilitySettings();
            },
            child: const Text('Mở cài đặt hỗ trợ tiếp cận'),
          ),
          if (_canAddTile)
            OutlinedButton(
              onPressed: () async {
                final added = await _platform.requestAddTile();
                if (!added && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chưa gắn được ô Quick Settings')),
                  );
                }
              },
              child: const Text('Gắn ô Quick Settings'),
            ),
        ],
      ),
    );
  }
}

double _snapSensitivity(double value) {
  final snapped = (value * 100).round() / 100;
  return snapped.clamp(0.08, 0.40).toDouble();
}

int _snapCooldown(double value) {
  final snapped = (value / 100).round() * 100;
  return snapped.clamp(800, 3000).toInt();
}
