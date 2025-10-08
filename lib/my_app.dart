import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/pages/auth/page_auth_check.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => getIt<ProviderLocale>()),
        ChangeNotifierProvider(create: (_) => getIt<ControllerAuth>()),
        Provider<ServiceStorage>(create: (_) => getIt<ServiceStorage>()),
        ChangeNotifierProvider(create: (_) => getIt<ControllerCalendar>()),
      ],
      child: Consumer<ProviderLocale>(builder: (context, providerLocale, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          locale: providerLocale.locale,
          supportedLocales: supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            primaryColor: Color(0xFF0066CC),
            scaffoldBackgroundColor: Colors.white,
            textTheme: Theme.of(context).textTheme.apply(
                  fontSizeFactor: 1.1,
                  bodyColor: Colors.black87,
                  displayColor: Colors.black87,
                ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Color(0xFF0066CC),
                padding: kGapEIH12V8,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF0066CC), // 藍色文字
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: Color(0xFF00BFA6), // 綠色文字
                side: const BorderSide(color: Color(0xFF00BFA6)),
              ),
            ),
            iconTheme: const IconThemeData(size: 36),
            appBarTheme: AppBarTheme(
              backgroundColor: Color(0xFF0066CC),
              iconTheme: IconThemeData(color: Colors.white),
              actionsIconTheme: IconThemeData(color: Colors.black),
              titleTextStyle: TextStyle(
                color: Colors.white,
              ),
              foregroundColor: Colors.white,
            ),
            inputDecorationTheme: InputDecorationTheme(
              floatingLabelStyle: TextStyle(color: Color(0xFF0066CC)),
              labelStyle: TextStyle(color: Colors.grey[700]),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueGrey),
              ),
            ),
          ),
          title: constAppTitle,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.5),
              ),
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
          debugShowMaterialGrid: false,
          showPerformanceOverlay: false,
          checkerboardRasterCacheImages: false,
          checkerboardOffscreenLayers: false,
          home: PageAuthCheck(
            setLocale: (value) => providerLocale.setLocale(locale: value),
          ),
        );
      })
    );
  }
}
