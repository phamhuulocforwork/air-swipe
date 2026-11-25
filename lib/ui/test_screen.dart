import 'dart:async';

import 'package:air_swipe/data/settings_store.dart';
import 'package:air_swipe/data/swipe_platform.dart';
import 'package:air_swipe/domain/gesture/wrist_swipe_tracker.dart';
import 'package:air_swipe/session/hand_session.dart';
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
  late final HandSession _session;

  var _shizukuGranted = false;
  var _shizukuRunning = false;
  var _canAddTile = false;
  var _sensitivity = 0.18;
  var _cooldownMs = 1500;
  var _upOnly = false;
  var _toggleBusy = false;
  var _debug = false;
  var _titleTaps = 0;
  Timer? _titleTapReset;
  int? _fps;
  int? _latencyMs;
  var _handVisible = false;
  var _hasSample = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = HandSession(platform: _platform);
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
      onHand: (arguments) async {
        final hand = HandEvent.fromArguments(arguments);
        if (mounted) {
          setState(() {
            _fps = hand.fps;
            _latencyMs = hand.latencyMs;
            _handVisible = hand.hasVisibleJoint;
            _hasSample = true;
          });
        }
        await _session.onHand(arguments);
      },
      onShizukuStatus: (status) {
        if (mounted) {
          setState(() {
            _shizukuGranted = status.granted;
            _shizukuRunning = status.running;
          });
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
      _upOnly = settings.upOnly;
      _canAddTile = canAddTile;
    });
    _applyTrackerSettings();
    await _refreshShizukuStatus();
    if (command == 'start') {
      await _setListening(true, collapse: true);
    } else if (command == 'stop') {
      await _setListening(false, collapse: false);
    }
  }

  void _applyTrackerSettings() {
    _session.tracker.sensitivity = _sensitivity;
    _session.tracker.cooldown = Duration(milliseconds: _cooldownMs);
    _session.tracker.upOnly = _upOnly;
  }

  Future<void> _refreshShizukuStatus() async {
    final status = await _platform.getShizukuStatus();
    if (mounted) {
      setState(() {
        _shizukuGranted = status.granted;
        _shizukuRunning = status.running;
      });
    }
  }

  Future<void> _saveSettings() {
    return _store.save(
      SwipeSettings(
        sensitivity: _sensitivity,
        cooldownMs: _cooldownMs,
        upOnly: _upOnly,
      ),
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
      _refreshShizukuStatus();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _platform.setPreviewActive(false);
    } else if (state == AppLifecycleState.detached) {
      _session.stop();
    }
  }

  void _onTitleTap() {
    _titleTapReset?.cancel();
    _titleTaps += 1;
    if (_titleTaps >= 5) {
      _titleTaps = 0;
      setState(() => _debug = !_debug);
      return;
    }
    _titleTapReset = Timer(const Duration(seconds: 2), () {
      _titleTaps = 0;
    });
  }

  @override
  void dispose() {
    _titleTapReset?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _session.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = 20.0;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: gap),
                      _powerButton(),
                      const SizedBox(height: gap),
                      _statusCard(),
                      if (_session.error != null) ...[
                        const SizedBox(height: gap),
                        _errorBanner(),
                      ],
                      if (_debug) ...[
                        const SizedBox(height: gap),
                        _previewCard(),
                        const SizedBox(height: 10),
                        _debugHint(),
                      ],
                      const SizedBox(height: gap),
                      _settingsCard(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _onTitleTap,
          behavior: HitTestBehavior.opaque,
          child: const Text(
            'AirSwipe',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: _ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Vuốt reels bằng cử chỉ tay — không cần chạm màn hình',
          style: TextStyle(fontSize: 14, height: 1.4, color: _body),
        ),
      ],
    );
  }

  Widget _powerButton() {
    final on = _session.listening || _session.starting;
    const size = 164.0;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: on
                ? [
                    BoxShadow(
                      color: const Color(0x52FFD74B),
                      blurRadius: 28,
                      offset: Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: on ? null : Border.all(color: _accent, width: 1.5),
            ),
            child: ClipOval(
              child: Material(
                color: on ? _accent : Colors.white,
                child: InkWell(
                  onTap: _toggleBusy
                      ? null
                      : () => _setListening(!on, collapse: false),
                  child: Ink(
                    width: size,
                    height: size,
                    decoration: on
                        ? const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_accentSoft, _accent],
                            ),
                          )
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.arrow_upward, size: 32, color: _ink),
                        const SizedBox(height: 10),
                        Text(
                          on ? 'Đang bật' : 'Bật',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          on ? 'Chạm để tắt' : 'Chạm để bật',
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFFF1F0),
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
      child: Text(
        _session.error!,
        style: const TextStyle(fontSize: 13, height: 1.4, color: _danger),
      ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: _cardDecoration,
      child: Column(
        children: [
          _statusRow(
            'Shizuku',
            _dotStatus(
              _shizukuRunning
                  ? (_shizukuGranted ? 'Đã cấp' : 'Chưa cấp')
                  : 'Chưa chạy',
              active: _shizukuGranted,
            ),
          ),
          const SizedBox(height: 14),
          _statusRow(
            'Camera',
            _dotStatus(
              _session.listening ? 'Đang hoạt động' : 'Tắt',
              active: _session.listening,
            ),
          ),
          const SizedBox(height: 14),
          _statusRow(
            'Thao tác gần nhất',
            Text(
              _gestureLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, Widget trailing) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: _body)),
        const Spacer(),
        trailing,
      ],
    );
  }

  Widget _dotStatus(String text, {required bool active}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _ok : _line,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
      ],
    );
  }

  Widget _settingsCard() {
    final seconds = (_cooldownMs / 1000).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tuỳ chỉnh',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Độ nhạy cử chỉ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _ink,
            ),
          ),
          Slider(
            min: _sensitivityMin,
            max: _sensitivityMax,
            value: _sliderSensitivity(_sensitivity),
            onChanged: (value) {
              setState(() {
                _sensitivity = _snapSensitivity(_sliderSensitivity(value));
              });
              _applyTrackerSettings();
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ít nhạy', style: TextStyle(fontSize: 12, color: _muted)),
              Text('Rất nhạy', style: TextStyle(fontSize: 12, color: _muted)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Khoảng nghỉ giữa 2 lần vuốt',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '$seconds giây',
                style: const TextStyle(fontSize: 13, color: _muted),
              ),
            ],
          ),
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
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chỉ vuốt lên',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tắt để vuốt được cả hai chiều',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _upOnly,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (value) {
                  setState(() => _upOnly = value);
                  _applyTrackerSettings();
                  _saveSettings();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    final listening = _session.listening;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Xem trước camera',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (listening)
                    const AndroidView(viewType: 'com.airswipe/preview')
                  else
                    const ColoredBox(color: _ink),
                  const _FrameCorner(alignment: Alignment.topLeft),
                  const _FrameCorner(alignment: Alignment.topRight),
                  const _FrameCorner(alignment: Alignment.bottomLeft),
                  const _FrameCorner(alignment: Alignment.bottomRight),
                  Center(
                    child: Text(
                      listening ? 'Đang nhận diện tay…' : 'Camera tắt',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fpsLabel, style: _mono),
              Text(_latencyLabel, style: _mono),
              Text(_handLabel, style: _mono),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final shizukuButton = _outlineButton(
      'Yêu cầu quyền Shizuku',
      () async {
        final status = await _platform.requestShizukuPermission();
        if (!context.mounted) return;
        if (!status.running) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Shizuku chưa chạy — mở app Shizuku, bấm Start (Wireless debugging) rồi quay lại.',
              ),
            ),
          );
        }
        setState(() {
          _shizukuGranted = status.granted;
          _shizukuRunning = status.running;
        });
      },
    );
    if (!_canAddTile) {
      return shizukuButton;
    }
    return Row(
      children: [
        Expanded(child: shizukuButton),
        const SizedBox(width: 10),
        Expanded(
          child: _outlineButton('Thêm lối tắt nhanh', () async {
            final added = await _platform.requestAddTile();
            if (!added && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chưa gắn được ô Quick Settings')),
              );
            }
          }),
        ),
      ],
    );
  }

  Widget _outlineButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink,
          backgroundColor: Colors.white,
          side: const BorderSide(color: _accent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label, textAlign: TextAlign.center, maxLines: 2),
      ),
    );
  }

  Widget _debugHint() {
    return const Text(
      'Chạm 5 lần liên tiếp vào chữ "AirSwipe" để tắt chế độ Debug.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.5, color: _muted),
    );
  }

  String get _gestureLabel {
    return switch (_session.lastGesture) {
      SwipeDirection.up => 'Vuốt lên ↑',
      SwipeDirection.down => 'Vuốt xuống ↓',
      null => '—',
    };
  }

  String get _fpsLabel {
    if (!_session.listening || _fps == null) {
      return 'FPS: —';
    }
    return 'FPS: $_fps';
  }

  String get _latencyLabel {
    if (!_session.listening || _latencyMs == null) {
      return 'Độ trễ: —';
    }
    return 'Độ trễ: $_latencyMs ms';
  }

  String get _handLabel {
    if (!_session.listening || !_hasSample) {
      return 'Tay: —';
    }
    return _handVisible ? 'Tay: phát hiện' : 'Tay: không thấy';
  }
}

class _FrameCorner extends StatelessWidget {
  const _FrameCorner({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final top = alignment.y < 0;
    final left = alignment.x < 0;
    return Align(
      alignment: alignment,
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            top: top ? _side : BorderSide.none,
            bottom: top ? BorderSide.none : _side,
            left: left ? _side : BorderSide.none,
            right: left ? BorderSide.none : _side,
          ),
        ),
      ),
    );
  }
}

const _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: [
    BoxShadow(color: Color(0x0F1C1B1F), blurRadius: 3, offset: Offset(0, 1)),
  ],
);

const _mono = TextStyle(fontSize: 12, color: _muted, fontFamily: 'monospace');

const _side = BorderSide(color: Color(0x8CFFFFFF), width: 2);

const _bg = Color(0xFFFFFBF0);
const _ink = Color(0xFF1C1B1F);
const _body = Color(0xFF49454F);
const _muted = Color(0xFF635E6B);
const _accent = Color(0xFFFFD74B);
const _accentSoft = Color(0xFFFFE7A3);
const _line = Color(0xFFCAC4D0);
const _ok = Color(0xFF1E8E3E);
const _danger = Color(0xFFB3261E);

const _sensitivityMin = 0.08;
const _sensitivityMax = 0.40;

double _sliderSensitivity(double threshold) {
  return _sensitivityMax + _sensitivityMin - threshold;
}

double _snapSensitivity(double value) {
  final snapped = (value * 100).round() / 100;
  return snapped.clamp(0.08, 0.40).toDouble();
}

int _snapCooldown(double value) {
  final snapped = (value / 100).round() * 100;
  return snapped.clamp(800, 3000).toInt();
}
