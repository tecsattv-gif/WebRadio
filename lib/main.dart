import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/radio_handler.dart';

late final RadioHandler radio;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  radio = await AudioService.init(
    builder: () => RadioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tecsattv.webradio.audio',
      androidNotificationChannelName: 'Rádio tocando',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
  );
  await radio.init();
  runApp(const WebRadioApp());
}

class WebRadioApp extends StatelessWidget {
  const WebRadioApp({super.key});

  static const Color seed = Color(0xFFFF8A1F);

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).copyWith(
      primary: seed,
      surface: const Color(0xFF16110D),
    );
    return MaterialApp(
      title: 'WebRádio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFF110D0A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF110D0A),
          centerTitle: false,
        ),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      ),
      home: const HomeScreen(),
    );
  }
}
