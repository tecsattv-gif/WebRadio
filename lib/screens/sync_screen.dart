import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../services/sync_service.dart';
import '../widgets/format.dart';

class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  SyncService get _sync => radio.sync;

  void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _create(BuildContext context) async {
    final err = await _sync.createCode();
    if (context.mounted && err != null) _snack(context, err);
  }

  Future<void> _join(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usar código de outro celular'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A lista do outro celular vai substituir a lista deste aparelho.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'XXXX-XXXX-XXXX-XXXX',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Usar'),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    final err = await _sync.joinCode(text);
    if (!context.mounted) return;
    _snack(context, err ?? 'Lista sincronizada!');
  }

  Future<void> _stop(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parar de sincronizar?'),
        content: const Text(
            'A lista continua neste celular, mas as mudanças não vão mais para os outros aparelhos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Parar')),
        ],
      ),
    );
    if (ok == true) await _sync.stopSync();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sincronizar celulares')),
      body: ListenableBuilder(
        listenable: Listenable.merge(
            [_sync.code, _sync.busy, _sync.lastError, _sync.lastSync]),
        builder: (context, _) {
          final code = _sync.code.value;
          final busy = _sync.busy.value;
          return ListView(
            padding: EdgeInsets.symmetric(
                horizontal: sideGutter(MediaQuery.sizeOf(context).width, base: 20), vertical: 20),
            children: [
              const Text(
                'Use o mesmo código em todos os seus celulares e a lista de rádios fica igual em todos. '
                'Quem tiver o código vê e altera a lista, então só passe para quem você quiser.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              if (code == null) ...[
                FilledButton.icon(
                  onPressed: busy ? null : () => _create(context),
                  icon: const Icon(Icons.add_link),
                  label: const Text('Criar código para este celular'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _join(context),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Já tenho um código'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('Seu código', style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      SelectableText(
                        SyncService.formatCode(code),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: SyncService.formatCode(code)));
                          _snack(context, 'Código copiado.');
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copiar'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: busy
                      ? const SizedBox(
                          width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(
                          _sync.lastError.value == null ? Icons.cloud_done : Icons.cloud_off,
                          color: _sync.lastError.value == null
                              ? Colors.greenAccent
                              : Colors.orangeAccent,
                        ),
                  title: Text(busy
                      ? 'Sincronizando…'
                      : (_sync.lastError.value ??
                          (_sync.lastSync.value == null
                              ? 'Ainda não sincronizou'
                              : 'Sincronizado em ${formatDate(_sync.lastSync.value!)}'))),
                  trailing: IconButton(
                    tooltip: 'Sincronizar agora',
                    icon: const Icon(Icons.sync),
                    onPressed: busy
                        ? null
                        : () async {
                            final err = await _sync.syncNow();
                            if (context.mounted) _snack(context, err ?? 'Lista sincronizada.');
                          },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'No outro celular, abra esta tela, toque em "Já tenho um código" e digite o código acima.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _stop(context),
                  icon: const Icon(Icons.link_off),
                  label: const Text('Parar de sincronizar'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
