import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_info.dart';
import '../providers/providers.dart';
import '../theme/app_typography.dart';
import '../theme/dimens.dart';
import 'settings_pages.dart';

// Alias de commodité — le projet utilise AppSpacing, pas Dimens.
const double _xs = AppSpacing.xs;
const double _s = AppSpacing.sm;
const double _m = AppSpacing.md2;
const double _l = AppSpacing.xl;

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final v = await AppInfo.version();
    if (mounted) setState(() => _version = v);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final lock = ref.watch(lockSettingsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: _m, vertical: _s),
        children: [
          // Apparence
          _CategoryCard(
            icon: Icons.palette_outlined,
            iconColor: Colors.deepPurple,
            title: s.appearanceSettings,
            subtitle: '${s.theme}: ${settings.themeMode.name} • ${settings.fontFamily}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppearanceSettingsPage()),
            ),
          ),

          // Notifications & Alarme
          _CategoryCard(
            icon: Icons.notifications_active_outlined,
            iconColor: Colors.amber.shade800,
            title: s.notificationSettings,
            subtitle: '${s.alarmMode}: ${settings.alarmMode ? s.enabled : s.disabled}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationSettingsPage()),
            ),
          ),

          // Sécurité & Verrou
          _CategoryCard(
            icon: Icons.lock_outline_rounded,
            iconColor: Colors.blue.shade700,
            title: s.securitySettings,
            subtitle: '${s.lockApp}: ${lock.enabled ? lockMethodLabel(s, lock.method) : s.disabled}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
            ),
          ),

          // Langue & RTL
          _CategoryCard(
            icon: Icons.language_outlined,
            iconColor: Colors.teal,
            title: s.languageSettings,
            subtitle: settings.locale.toUpperCase(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
            ),
          ),

          // Données & Catégories
          _CategoryCard(
            icon: Icons.storage_outlined,
            iconColor: Colors.indigo,
            title: s.dataManagement,
            subtitle: s.manageCategories,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DataSettingsPage()),
            ),
          ),

          // À propos
          _CategoryCard(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.pink,
            title: s.aboutApp,
            subtitle: s.versionInfo.replaceAll('{version}', _version ?? '1.0.0+1'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutSettingsPage()),
            ),
          ),

          const SizedBox(height: _l),
          Center(
            child: Text(
              '${s.appName} • ${_version ?? '1.0.0+1'}',
              style: AppTypography.bodySmall.copyWith(color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: _m),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: _m, vertical: _xs),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: AppTypography.titleMedium.copyWith(fontWeight: AppTypography.w700),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
        onTap: onTap,
      ),
    );
  }
}
