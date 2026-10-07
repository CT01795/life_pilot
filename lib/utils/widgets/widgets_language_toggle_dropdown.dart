import 'package:flutter/material.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:provider/provider.dart';

class LanguageToggleDropdown extends StatelessWidget {
  final bool compact;

  const LanguageToggleDropdown({super.key, this.compact = false});

  String getLanguageDisplayName(BuildContext context, String code) {
    final loc = AppLocalizations.of(context)!;
    switch (code) {
      case Locales.en:
        return loc.languageEnglish;
      case Locales.zh:
        return loc.languageChinese;
      case Locales.ja:
        return loc.languageJapanese;
      case Locales.ko:
        return loc.languageKorean;
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<ProviderLocale>();
    return PopupMenuButton<Locale>(
      initialValue: locale.locale,
      tooltip: AppLocalizations.of(context)!.language,
      color: const Color(0xFF0066CC),
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 220),
      position: PopupMenuPosition.under,
      onSelected: (newLocale) {
        context.read<ProviderLocale>().setLocale(locale: newLocale);
      },
      itemBuilder: (context) {
        return AppConfig.supportedLocales.map((itemLocale) {
          final isSelected = itemLocale == locale.locale;
          return PopupMenuItem<Locale>(
            value: itemLocale,
            height: kMinInteractiveDimension,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : null,
                ),
                Gaps.w8,
                Expanded(
                  child: Text(
                    getLanguageDisplayName(context, itemLocale.languageCode),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: SizedBox(
        width: compact ? 64 : null,
        height: kToolbarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.language, color: Colors.white, size: 28),
              if (!compact) ...[
                Gaps.w8,
                Text(
                  getLanguageDisplayName(context, locale.locale.languageCode),
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
