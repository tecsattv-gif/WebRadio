import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

/// Ícone discreto que abre as configurações de Bluetooth do Android
/// (para conectar caixa de som, fone ou o carro).
class BluetoothButton extends StatelessWidget {
  const BluetoothButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Bluetooth',
      visualDensity: VisualDensity.compact,
      iconSize: 20,
      icon: const Icon(Icons.bluetooth, color: Colors.white38),
      onPressed: () async {
        try {
          await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Não consegui abrir o Bluetooth. Abra pelas configurações do Android.')));
          }
        }
      },
    );
  }
}
