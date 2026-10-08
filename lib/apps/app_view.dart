import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/apps/config_app.dart';
import 'package:life_pilot/auth/service_auth.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
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
    if (state != AppLifecycleState.resumed || !mounted) return;
    unawaited(_validateCurrentAccount(force: true));
    if (!kIsWeb) {
      context.read<ControllerCalendar>().syncCompletedEventReminders();
    }
  }

  Future<void> _validateCurrentAccount({
    bool force = false,
    BuildContext? messageContext,
  }) async {
    final localizationContext =
        messageContext ?? app_navigator.navigatorKey.currentContext;
    final message = localizationContext == null
        ? null
        : AppLocalizations.of(localizationContext)?.accountNoLongerAvailable;
    final result = await context.read<ControllerAuth>().validateCurrentAccount(
      force: force,
    );
    if (!mounted || result != AccountValidationResult.signedOut) return;
    if (message != null) app_navigator.AppNavigator.showErrorBar(message);
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
    ServiceAuth.capturePasswordRecoveryUri(uri);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: app_navigator.rootRepaintBoundaryKey,
      child: Selector<ProviderLocale, Locale>(
        selector: (_, provider) => provider.locale,
        builder: (_, locale, _) {
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
              final scaleFactor = mediaQuery.textScaler
                  .scale(1)
                  .clamp(1.5, 2.0)
                  .toDouble();

              final content =
                  Selector<
                    ControllerAuth,
                    ({
                      bool visible,
                      bool loggedIn,
                      int? endingInDays,
                      DateTime? endsAt,
                    })
                  >(
                    selector: (_, auth) => (
                      visible:
                          auth.quotaFreePeriodActive &&
                          !auth.isSysAdmin &&
                          !auth.isVendor,
                      loggedIn: auth.isLoggedIn && !auth.isAnonymous,
                      endingInDays: auth.quotaFreePeriodEndingInDays,
                      endsAt: auth.quotaFreePeriodEndsAt,
                    ),
                    builder: (context, state, _) {
                      final showPromotion = state.visible && state.loggedIn;
                      final scaledMediaQuery = mediaQuery.copyWith(
                        textScaler: TextScaler.linear(scaleFactor),
                      );
                      if (!showPromotion) {
                        return MediaQuery(
                          data: scaledMediaQuery,
                          child: child ?? const SizedBox.shrink(),
                        );
                      }
                      final loc = AppLocalizations.of(context)!;
                      final localEnd = state.endsAt?.toLocal();
                      final endLabel = localEnd == null
                          ? null
                          : '${MaterialLocalizations.of(context).formatCompactDate(localEnd)} '
                                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(localEnd))}';
                      return MediaQuery(
                        data: scaledMediaQuery,
                        child: Column(
                          children: [
                            SafeArea(
                              bottom: false,
                              child: Material(
                                color: Theme.of(
                                  context,
                                ).colorScheme.tertiaryContainer,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.celebration_outlined),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 2,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              loc.quotaFreePeriodUserBannerShort,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelLarge,
                                            ),
                                            _PromotionDetailsHint(
                                              label: loc
                                                  .quotaFreePeriodDetailsHint,
                                              message:
                                                  loc.quotaFreePeriodUserBanner,
                                            ),
                                            if (endLabel != null)
                                              Text(
                                                state.endingInDays == 0
                                                    ? loc.quotaFreePeriodEndingToday
                                                    : loc.quotaFreePeriodEndsOn(
                                                        endLabel,
                                                      ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: MediaQuery(
                                data: scaledMediaQuery.removePadding(
                                  removeTop: true,
                                ),
                                child: child ?? const SizedBox.shrink(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
              return Focus(
                canRequestFocus: false,
                onKeyEvent: (_, _) {
                  unawaited(_validateCurrentAccount(messageContext: context));
                  return KeyEventResult.ignored;
                },
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => unawaited(
                    _validateCurrentAccount(messageContext: context),
                  ),
                  child: content,
                ),
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

class _PromotionDetailsHint extends StatefulWidget {
  const _PromotionDetailsHint({required this.label, required this.message});

  final String label;
  final String message;

  @override
  State<_PromotionDetailsHint> createState() => _PromotionDetailsHintState();
}

class _PromotionDetailsHintState extends State<_PromotionDetailsHint> {
  bool _detailsVisible = false;

  void _setDetailsVisible(bool visible) {
    if (_detailsVisible == visible) return;
    setState(() => _detailsVisible = visible);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _setDetailsVisible(true),
      onExit: (_) => _setDetailsVisible(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setDetailsVisible(!_detailsVisible),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            if (_detailsVisible)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.message,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
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
