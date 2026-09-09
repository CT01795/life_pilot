import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/auth/page_auth_check.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/utils/app_navigator.dart' as app_navigator;
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/theme.dart';
import 'package:provider/provider.dart';

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    app_navigator.AppNavigator.initErrorHandling();
    _initDeepLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || kIsWeb || !mounted) return;
    context.read<ControllerCalendar>().syncCompletedEventReminders();
  }

  Future<void> _initDeepLink() async {
    if (kIsWeb) {
      _handleDeepLink(Uri.base);
      return;
    }

    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleDeepLink(initialUri);
    _deepLinkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) {
    final sanitizedUri = uri.replace(query: null, fragment: null);
    logger.i('DeepLink received: $sanitizedUri');
    final fragment = uri.fragment;
    final fragmentQuery = fragment.contains('?')
        ? fragment.substring(fragment.indexOf('?') + 1)
        : fragment;
    Map<String, String> fragmentParameters = const {};
    try {
      fragmentParameters = Uri.splitQueryString(fragmentQuery);
    } on FormatException catch (error, stackTrace) {
      logger.e(
        'Invalid password recovery URL fragment',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final isRecovery = uri.host == 'reset-password' ||
        uri.path.contains('reset-password') ||
        uri.queryParameters['type'] == 'recovery' ||
        fragmentParameters['type'] == 'recovery';
    if (isRecovery) ServiceAuth.markPasswordRecoveryLink();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: app_navigator.rootRepaintBoundaryKey,
      child: Selector<ProviderLocale, Locale>(
        selector: (_, provider) => provider.locale,
        builder: (_, locale, __) {
          return MaterialApp(
            navigatorKey: app_navigator.navigatorKey,
            scaffoldMessengerKey: app_navigator.scaffoldMessengerKey,
            locale: locale,
            supportedLocales: AppConfig.supportedLocales,
            localizationsDelegates: AppConfig.localizationDelegates,
            theme: AppTheme.lightTheme,
            title: AppConfig.appTitle,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final scaleFactor =
                  mediaQuery.textScaler.scale(1).clamp(1.5, 2.0).toDouble();

              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(scaleFactor),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            debugShowCheckedModeBanner: false,
            home: const _AppHome(),
          );
        },
      ),
    );
  }
}

class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    return PageAuthCheck(
      setLocale: (value) =>
          context.read<ProviderLocale>().setLocale(locale: value),
    );
  }
}
