import 'package:flutter/material.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:provider/provider.dart';

class LanguageToggleDropdown extends StatelessWidget {
  const LanguageToggleDropdown({super.key});

  // 語言代碼對應名稱
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
    return DropdownButtonHideUnderline(
      child: DropdownButton<Locale>(
        value: locale.locale,
        dropdownColor: const Color(0xFF0066CC),
        alignment: Alignment.centerRight, // Flutter 3.7+ 支援，靠右顯示 dropdown 的選單
        icon: Icon(Icons.arrow_drop_down, color: Colors.white), // 自訂下拉箭頭顏色
        selectedItemBuilder: (BuildContext context) {
          return AppConfig.supportedLocales.map<Widget>((Locale locale) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end, // 靠右顯示
              children: [
                Icon(Icons.language, color: Colors.white, size: 30),
                Text(
                  getLanguageDisplayName(context, locale.languageCode),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            );
          }).toList();
        },
        items: AppConfig.supportedLocales.map((locale) {
          return DropdownMenuItem<Locale>(
            value: locale,
            child: Text(
              getLanguageDisplayName(context, locale.languageCode),
              style: TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            // 直接改 ProviderLocale
            context.read<ProviderLocale>().setLocale(locale: newLocale);
          }
        },
      ),
    );
  }
}
