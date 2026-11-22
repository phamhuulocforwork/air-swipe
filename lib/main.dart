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
    return const MaterialApp(title: 'AirSwipe', home: TestScreen());
  }
}
