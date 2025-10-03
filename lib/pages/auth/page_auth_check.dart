import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/auth/page_login.dart';
import 'package:life_pilot/pages/auth/page_register.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_main_page_bar.dart';
import 'package:provider/provider.dart';

class PageAuthCheck extends StatefulWidget {
  const PageAuthCheck({super.key, required this.setLocale});
  final Function(Locale) setLocale;
  @override
  State<PageAuthCheck> createState() => _PageAuthCheckState();
}

class _PageAuthCheckState extends State<PageAuthCheck> {
  late AppLocalizations _loc;
  bool _hasChecked = false;
  List<Widget> _appBarPages = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
    if (!_hasChecked) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      auth.checkLoginStatus(); // ✅ 啟動時檢查登入狀態
      _hasChecked = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final providerLocale = Provider.of<ProviderLocale>(context, listen: true);
    final auth = Provider.of<ControllerAuth>(context, listen: true);

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    Widget bodyWidget;

    switch (auth.currentPage) {
      case AuthPage.login:
        bodyWidget = PageLogin(
          email: auth.registerBackData[constEmail],
          password: auth.registerBackData[constPassword],
          onNavigateToRegister: (email, password) =>
              auth.goToRegister(email: email, password: password),
        );
        break;

      case AuthPage.register:
        bodyWidget = PageRegister(
          email: auth.registerBackData[constEmail],
          password: auth.registerBackData[constPassword],
          onBack: (email, password) =>
              auth.goBackToLogin(email: email, password: password),
        );
        break;

      case AuthPage.pageMain:
        bodyWidget = PageMain(
          onPagesChanged: (pages) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _appBarPages = pages;
              });
            });
          },
        );
        break;
    }
    return Scaffold(
      appBar: MainPageBar(
        title: _loc.appTitle,
        currentLocale: providerLocale.locale,
        onLocaleToggle: widget.setLocale,
        account: auth.isLoggedIn ? auth.currentAccount : null,
        onLogout: auth.isLoggedIn ? auth.logout : null,
        pages: auth.currentPage == AuthPage.pageMain ? _appBarPages : null,
      ),
      body: bodyWidget,
    );
  }
}
