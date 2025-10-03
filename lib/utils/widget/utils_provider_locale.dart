import 'package:flutter/material.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

class LanguageToggleDropdown extends StatelessWidget {
  final Locale currentLocale;
  final Function(Locale) onLocaleToggle;
  const LanguageToggleDropdown({
    super.key,
    required this.currentLocale,
    required this.onLocaleToggle,
  });

  // 語言代碼對應名稱
  String getLanguageDisplayName(String code) {
    switch (code) {
      case constLocaleEn:
        return 'EN';
      case constLocaleZh:
        return '中文';
      case constLocaleJa:
        return '日本語';
      case constLocaleKo:
        return '한국어';
      default:
        return code.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Locale>(
        value: currentLocale,
        dropdownColor: Colors.blueGrey[900],
        alignment: Alignment.centerRight, // Flutter 3.7+ 支援，靠右顯示 dropdown 的選單
        icon: Icon(Icons.arrow_drop_down, color: Colors.white), // 自訂下拉箭頭顏色
        selectedItemBuilder: (BuildContext context) {
          return supportedLocales.map<Widget>((Locale locale) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end, // 靠右顯示
              children: [
                Icon(Icons.language, color: Colors.white, size: 30),
                Text(
                  getLanguageDisplayName(locale.languageCode),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            );
          }).toList();
        },
        items: supportedLocales.map((locale) {
          return DropdownMenuItem<Locale>(
            value: locale,
            child: Text(
              getLanguageDisplayName(locale.languageCode),
              style: TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (Locale? newLocale) {
          if (newLocale != null) {
            onLocaleToggle(newLocale);
          }
        },
      ),
    );
  }
}