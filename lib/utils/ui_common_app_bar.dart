import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/providers/locale_provider.dart';
import 'package:life_pilot/utils/common_function.dart';
import 'package:provider/provider.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Locale currentLocale;
  final Function(Locale) onLocaleToggle;
  final String? account;
  final VoidCallback? onLogout;
  final List<Widget>? pages;

  const CommonAppBar({
    super.key,
    required this.title,
    required this.currentLocale,
    required this.onLocaleToggle,
    this.account,
    this.onLogout,
    this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProvider = Provider.of<LocaleProvider>(context);
    final auth = Provider.of<ControllerAuth>(context);
    final theme = Theme.of(context); // 抓取主題資料
    return AppBar(
      backgroundColor: theme.primaryColor, // 使用全域主色
      iconTheme: theme.iconTheme, // 套用 icon 樣式
      titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white), // 字體樣式
      title: Text((auth.currentAccount?.contains('@') ?? false)
            ? auth.currentAccount!.split('@')[0]
            : auth.currentAccount ?? title),
      actions: [
        if (pages != null) ...pages!, // ✅ 顯示傳進來的 pages（選單 dropdown 等）
        if ((auth.currentAccount != null && auth.currentAccount!.isNotEmpty))...[
          /*Text((auth.currentAccount?.contains('@') ?? false)
            ? auth.currentAccount!.split('@')[0]
            : auth.currentAccount ?? ''),
          kGapW8,*/
          IconButton(
            icon: Icon(Icons.exit_to_app),
            tooltip: loc.logout,
            onPressed: onLogout,
          ),
        ],        
        IconButton(
          icon: Icon(Icons.language),
          tooltip: loc.language,
          onPressed:  () {
            toggleLocale(localeProvider);
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
