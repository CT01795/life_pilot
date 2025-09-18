import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:provider/provider.dart';

class MainPageBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Locale currentLocale;
  final Function(Locale) onLocaleToggle;
  final String? account;
  final VoidCallback? onLogout;
  final List<Widget>? pages;

  const MainPageBar({
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
    final providerLocale = Provider.of<ProviderLocale>(context);
    final auth = Provider.of<ControllerAuth>(context,listen:false);
    final theme = Theme.of(context); 
    return AppBar(
      backgroundColor: theme.primaryColor, 
      iconTheme: theme.iconTheme, 
      //titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white), 
      title: Text((auth.currentAccount?.contains('@') ?? false)
            ? auth.currentAccount!.split('@')[0]
            : auth.currentAccount ?? title),
      actions: [
        if (pages != null) ...pages!, 
        if ((auth.currentAccount != null && auth.currentAccount!.isNotEmpty))...[
          IconButton(
            icon: Icon(Icons.exit_to_app),
            tooltip: loc.logout,
            onPressed: onLogout,
            color: Colors.white, 
          ),
        ],        
        IconButton(
          icon: Icon(Icons.language),
          tooltip: loc.language,
          onPressed:  () {
            toggleLocale(providerLocale);
          },
          color: Colors.white, 
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
