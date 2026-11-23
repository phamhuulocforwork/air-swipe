import 'package:air_swipe/ui/test_screen.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AirSwipeApp());
}

class AirSwipeApp extends StatelessWidget {
  const AirSwipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirSwipe',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBF0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD74B),
          surface: const Color(0xFFFFFBF0),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFFFFD74B),
          inactiveTrackColor: Color(0xFFE8E2D4),
          thumbColor: Color(0xFFFFD74B),
          overlayColor: Color(0x29FFD74B),
          trackHeight: 4,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF79747E);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFFFFD74B);
            }
            return const Color(0xFFE8E2D4);
          }),
          trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      home: const TestScreen(),
    );
  }
}
