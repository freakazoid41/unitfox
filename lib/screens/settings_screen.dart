import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/language_store.dart';
import '../l10n/app_strings.dart';
import '../theme.dart';
import '../widgets/language_flag.dart';

/// App settings: language picker (with country flags) + about card.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('en', 'English', 'EN'),
    ('tr', 'Türkçe', 'TR'),
    ('ru', 'Русский', 'RU'),
    ('fr', 'Français', 'FR'),
    ('de', 'Deutsch', 'DE'),
    ('hi', 'हिन्दी', 'HI'),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageStore>();
    final s = strings(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('settings.title')),
        centerTitle: true,
        bottom: AppBrand.barGradient,
      ),
      body: ListView(
        padding:
            const EdgeInsets.fromLTRB(16, 16, 16, 16 + AppBrand.bottomPad),
        children: [
          _SectionHeader(s.t('language')),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final l in _languages)
                  ListTile(
                    leading: LanguageFlag(code: l.$1),
                    title: Text(
                      l.$2,
                      style: TextStyle(
                        fontWeight: lang.lang == l.$1
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: lang.lang == l.$1
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: Text(l.$3,
                        style: Theme.of(context).textTheme.bodySmall),
                    trailing: lang.lang == l.$1
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 20)
                        : null,
                    onTap: () =>
                        context.read<LanguageStore>().setLocale(l.$1),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              s.t('settings.langIntro'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(s.t('settings.about')),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppBrand.teal.withValues(alpha: 0.12),
                radius: 22,
                child: Icon(Icons.pets, color: AppBrand.teal, size: 22),
              ),
              title: const Text('Unitfox',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(s.t('settings.aboutBody'),
                  style: Theme.of(context).textTheme.bodySmall),
              isThreeLine: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      );
}
