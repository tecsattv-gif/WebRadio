import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cadeado: trava os toques na tela (não troca rádio, não fecha o app).
/// Opcionalmente fixa a tela do Android (impede sair pelo botão de início).
class LockService {
  static const _channel = MethodChannel('webradio/lock');
  static const _kPin = 'lock_pin_screen';

  static final ValueNotifier<bool> locked = ValueNotifier(false);
  static final ValueNotifier<bool> pinScreen = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    pinScreen.value = prefs.getBool(_kPin) ?? false;
  }

  static Future<void> setPinScreen(bool v) async {
    pinScreen.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPin, v);
  }

  static Future<void> lock() async {
    locked.value = true;
    HapticFeedback.mediumImpact();
    if (pinScreen.value) {
      try {
        await _channel.invokeMethod('pin');
      } catch (_) {}
    }
  }

  static Future<void> unlock() async {
    locked.value = false;
    HapticFeedback.mediumImpact();
    try {
      await _channel.invokeMethod('unpin');
    } catch (_) {}
  }
}
