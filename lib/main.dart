import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/pages/page_register.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/notification/notification.dart';
import 'package:life_pilot/utils/utils_main_page_bar.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_timezone_helper.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/controller_auth.dart';
import 'l10n/app_localizations.dart';
import 'pages/page_login.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async { 
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ 初始化時區
  constTzLocation = await setTimezoneFromDevice(); // ✅ 自動偵測並設定時區

  // ✅ 初始化 Firebase、Supabase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: constSupabaseUrl,
    anonKey: constSupabaseAnonKey,
  );

  // 只呼叫一次 NotificationService 的初始化
  await MyCustomNotification.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ControllerAuth()),
        ChangeNotifierProvider(
          create: (_) => ProviderLocale(locale: Locale(constLocaleZh))),  
        ChangeNotifierProvider(
          create: (_) => ControllerCalendar(tableName: constTableCalendarEvents)),  
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ProviderLocale>(
        builder: (context, providerLocale, child) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        title: constAppTitle,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5),),
            child: child!,
          );
        },
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale(constLocaleEn),
          Locale(constLocaleZh),
        ],
        locale: providerLocale.locale, 
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
        debugShowCheckedModeBanner: false,
        debugShowMaterialGrid: false,
        showPerformanceOverlay: false,
        checkerboardRasterCacheImages: false,
        checkerboardOffscreenLayers: false,
        home: AuthCheckPage(
          setLocale: (locale) {
            providerLocale.setLocale(locale); 
          },
        ),
      );
    });
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key, required this.setLocale});
  final Function(Locale) setLocale;

  @override
  State<AuthCheckPage> createState() => _AuthCheckPageState();
}

enum AuthPage { login, register, pageMain }

class _AuthCheckPageState extends State<AuthCheckPage> {
  AppLocalizations get loc => AppLocalizations.of(context)!; 
  AuthPage currentPage = AuthPage.login;
  Map<String, String> registerBackData = {constEmail: constEmpty, constPassword: constEmpty};
  List<Widget> _appBarPages = [];

  @override
  void initState() {
    super.initState();

    // ✅ 延遲初始化 login 檢查，避免在 widget 還沒 mount 就觸發
    Future.microtask(() {
      if (mounted) {
        Provider.of<ControllerAuth>(context, listen: false).checkLoginStatus();
      }
    });
  }

  void _goToRegister([String? email, String? password]) {
    if (!mounted) return;
    setState(() {
      registerBackData[constEmail] = email!;
      registerBackData[constPassword] = password!;
      currentPage = AuthPage.register;
    });
  }

  void _goBackToLogin(String? email, String? password) {
    registerBackData[constEmail] = email!;
    registerBackData[constPassword] = password!;
    if (!mounted) return;
    setState(() {
      currentPage = AuthPage.login;
    });
  }

  void _logout() async {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final currentEmail = auth.currentAccount != null &&
            auth.currentAccount!.isNotEmpty &&
            !auth.isAnonymous
        ? auth.currentAccount
        : constEmpty;
    await auth.logout(context);
    if (!mounted) return;
    setState(() {
      registerBackData[constEmail] = currentEmail!;
      currentPage = AuthPage.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControllerAuth>(context);
    final providerLocale =
        Provider.of<ProviderLocale>(context); 
    if (auth.isLoading) return Center(child: CircularProgressIndicator());

    Widget bodyWidget;

    // 登入狀態決定 currentPage，不直接改 currentPage，避免 rebuild 問題
    final bool loggedIn = auth.isLoggedIn;

    if (loggedIn) {
      if (currentPage != AuthPage.pageMain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            currentPage = AuthPage.pageMain;
          });
        });
      }
    } else {
      if (currentPage == AuthPage.pageMain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            currentPage = AuthPage.login;
          });
        });
      }
    }

    // 依 currentPage 決定 bodyWidget 與 title
    switch (currentPage) {
      case AuthPage.login:
        bodyWidget = PageLogin(
          email: registerBackData[constEmail],
          password: registerBackData[constPassword],
          onNavigateToRegister: _goToRegister,
        );
        break;

      case AuthPage.register:
        bodyWidget = PageRegister(
          email: registerBackData[constEmail],
          password: registerBackData[constPassword],
          onBack: _goBackToLogin,
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
        title: loc.appTitle,
        currentLocale: providerLocale.locale, 
        onLocaleToggle: widget.setLocale,
        account: auth.isLoggedIn ? auth.currentAccount : null,
        onLogout: auth.isLoggedIn ? _logout : null,
        pages: currentPage == AuthPage.pageMain
            ? _appBarPages
            : null, 
      ),
      body: bodyWidget,
    );
  }
}
