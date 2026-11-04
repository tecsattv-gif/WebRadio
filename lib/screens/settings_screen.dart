import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/update_service.dart';
import '../widgets/format.dart';
import 'backup_screen.dart';
import 'radio_search_tab.dart';
import 'recordings_screen.dart';
import 'suggested_screen.dart';
import 'sync_screen.dart';

/// Configurações: aba "Buscar rádios" e aba "Geral".
class SettingsScreen extends StatelessWidget {
  final int initialTab;
  const SettingsScreen({super.key, this.initialTab = 0});

  static Future<void> open(BuildContext context, {int tab = 0}) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsScreen(initialTab: tab)),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configurações'),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF8A1F),
            labelColor: Color(0xFFFF8A1F),
            tabs: [
              Tab(icon: Icon(Icons.travel_explore), text: 'Buscar rádios'),
              Tab(icon: Icon(Icons.tune), text: 'Geral'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            RadioSearchTab(),
            _GeneralTab(),
          ],
        ),
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

  void _go(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Future<void> _about(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'WebRádio',
      applicationVersion: 'Versão ${info.version}',
      applicationIcon: const Icon(Icons.radio_rounded, size: 40, color: Color(0xFFFF8A1F)),
      children: const [
        SizedBox(height: 8),
        Text('Criado por Luiz Alberto Cardoso'),
        Text('tecsattv@gmail.com'),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = sideGutter(MediaQuery.sizeOf(context).width, base: 0, maxContent: 720);
    Widget tile(IconData icon, String title, String sub, VoidCallback onTap) => ListTile(
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A1F).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF8A1F)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 8),
      children: [
        tile(Icons.explore_outlined, 'Rádios sugeridas', 'Lista pública do WebRádio',
            () => _go(context, const SuggestedScreen())),
        tile(Icons.sync, 'Sincronizar celulares', 'Mesma lista em vários aparelhos',
            () => _go(context, const SyncScreen())),
        tile(Icons.save_alt, 'Backup e restauração', 'Salvar, compartilhar e restaurar a lista',
            () => _go(context, const BackupScreen())),
        tile(Icons.library_music_outlined, 'Gravações', 'Ouvir, compartilhar e apagar',
            () => _go(context, const RecordingsScreen())),
        const Divider(),
        tile(Icons.system_update, 'Procurar atualização', 'Ver se há versão nova',
            () => UpdateService.checkManually(context)),
        tile(Icons.info_outline, 'Sobre', 'Versão e créditos', () => _about(context)),
      ],
    );
  }
}
