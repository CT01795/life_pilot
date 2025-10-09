import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/auth/page_login.dart';
import 'package:life_pilot/pages/auth/page_register.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/providers/provider.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/widget/utils_provider_locale.dart';
import 'package:provider/provider.dart';

class PageAuthCheck extends StatefulWidget {
  const PageAuthCheck({super.key, required this.setLocale});
  final Function(Locale) setLocale;
  @override
  State<PageAuthCheck> createState() => _PageAuthCheckState();
}

class _PageAuthCheckState extends State<PageAuthCheck> {
  late AppLocalizations _loc;

  @override
  void initState() {
    super.initState();
    // ✅ 延後檢查登入狀態，避免在 build 階段觸發 notifyListeners()
    // 避免在 build() 或 didChangeDependencies() 內做 setState() 或 notifyListeners()。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      auth.checkLoginStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
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

    return ValueListenableBuilder<List<Widget>>(
      valueListenable: appBarWidgetsProvider,
      builder: (_, pages, __) {
        return Scaffold(
            appBar: MainPageBar(
            title: _loc.appTitle,
            currentLocale: providerLocale.locale,
            onLocaleToggle: widget.setLocale,
            account: auth.isLoggedIn ? auth.currentAccount : null,
            onLogout: auth.isLoggedIn ? auth.logout : null,
            pages: auth.currentPage == AuthPage.pageMain ? pages : null,
          ),
          body: _buildBody(auth),
        );
      },
    );
  }

  Widget _buildBody(ControllerAuth auth) {
    switch (auth.currentPage) {
      case AuthPage.login:
        return PageLogin(
          email: auth.registerBackData[constEmail],
          password: auth.registerBackData[constPassword],
          onNavigateToRegister: (email, password) =>
              auth.goToRegister(email: email, password: password),
        );
      case AuthPage.register:
        return PageRegister(
          email: auth.registerBackData[constEmail],
          password: auth.registerBackData[constPassword],
          onBack: (email, password) =>
              auth.goBackToLogin(email: email, password: password),
        );
      case AuthPage.pageMain:
        return const PageMain(); // ✅ 交由 PageMain 自己決定 Controller
    }
  }
}

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
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.primaryColor,
      iconTheme: theme.iconTheme,
      //titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
      title: Text((account?.contains('@') ?? false)
          ? account!.split('@')[0]
          : account ?? title),
      actions: [
        if (pages != null) ...pages!,
        LanguageToggleDropdown(
          currentLocale: currentLocale,
          onLocaleToggle: onLocaleToggle,
        ),
        if ((account != null && account!.isNotEmpty)) ...[
          IconButton(
            icon: Icon(Icons.exit_to_app),
            tooltip: loc.logout,
            onPressed: onLogout,
            color: Colors.white,
          ),
        ],
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
