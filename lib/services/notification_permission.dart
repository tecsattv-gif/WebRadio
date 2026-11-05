import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Permissão de notificação (Android 13+). Sem ela, o Android/Xiaomi
/// pode parar a rádio em segundo plano.
class NotificationPermission {
  static const _kAsked = 'asked_notification_permission';
  static const _ch = MethodChannel('webradio/notif');

  static Future<bool> _granted() async {
    try {
      return await _ch.invokeMethod<bool>('granted') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _request() async {
    try {
      await _ch.invokeMethod('request');
    } catch (_) {}
    // A resposta vem numa janela do Android: confere de novo em seguida.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (await _granted()) break;
    }
  }

  /// true quando a notificação está bloqueada (mostra o aviso na tela inicial).
  static final ValueNotifier<bool> blocked = ValueNotifier(false);

  static Future<void> refresh() async {
    try {
      blocked.value = !(await _granted());
    } catch (_) {
      blocked.value = false;
    }
  }

  /// Ao abrir o app: explica e pede uma vez; depois só mostra o aviso.
  static Future<void> checkOnStart(BuildContext context) async {
    try {
      if (await _granted()) {
        blocked.value = false;
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kAsked) ?? false) {
        blocked.value = true;
        return;
      }
      await prefs.setBool(_kAsked, true);
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.notifications_active_outlined, color: Color(0xFFFF8A1F)),
          title: const Text('Permitir notificações'),
          content: const Text(
              'Com a notificação ligada, a rádio continua tocando quando você usa outros apps '
              'ou apaga a tela, e os controles aparecem na tela de bloqueio.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Agora não')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Permitir')),
          ],
        ),
      );
      if (ok == true) await _request();
      await refresh();
    } catch (_) {}
  }

  /// Pede de novo; se o Android não deixar mais pedir, abre as configurações do app.
  static Future<void> fix() async {
    try {
      await _request();
      if (!await _granted()) await _ch.invokeMethod('settings');
    } catch (_) {}
    await refresh();
  }
}

/// Faixa de aviso na tela inicial quando a notificação está bloqueada.
class NotificationWarning extends StatelessWidget {
  const NotificationWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NotificationPermission.blocked,
      builder: (context, blocked, _) {
        if (!blocked) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Material(
            color: Colors.orangeAccent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: NotificationPermission.fix,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.notifications_off_outlined, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notificações desligadas: a rádio pode parar em segundo plano. Toque para ativar.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
