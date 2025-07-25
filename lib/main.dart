import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/pages/page_register.dart';
import 'package:life_pilot/providers/locale_provider.dart';
import 'package:life_pilot/utils/ui_common_app_bar.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/controller_auth.dart';
import 'l10n/app_localizations.dart';
import 'pages/page_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 初始化 Supabase
  await Supabase.initialize(
    url: 'https://ccktdpycnferbrjrdtkp.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNja3RkcHljbmZlcmJyanJkdGtwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTMyNTU0NTIsImV4cCI6MjA2ODgzMTQ1Mn0.jsuY3AvuhRlCwuGKmcq_hyj1ViLRX18kmQs5YYnFwR4',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => ControllerAuth()..checkLoginStatus()),
        ChangeNotifierProvider(
            create: (_) => LocaleProvider(locale: Locale('zh'))), // 提供初始語言設置
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
    return Consumer<LocaleProvider>(// 使用 Consumer 來監聽 LocaleProvider
        builder: (context, localeProvider, child) {
      return MaterialApp(
        title: 'Life Pilot',
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('zh'),
        ],
        locale: localeProvider.locale, // 從 provider 拿 locale
        theme: ThemeData(primarySwatch: Colors.blue),
        debugShowCheckedModeBanner: false,
        home: AuthCheckPage(
          setLocale: (locale) {
            localeProvider.setLocale(locale); // 改變 provider 狀態
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
  AuthPage currentPage = AuthPage.login;
  Map<String, String> registerBackData = {'email': '', 'password': ''};
  List<Widget> _appBarPages = [];  // <== 這裡改成成員變數

  void _goToRegister([String? email, String? password]) {
    setState(() {
      registerBackData['email'] = email!;
      registerBackData['password'] = password!;
      currentPage = AuthPage.register;
    });
  }

  void _goBackToLogin(String? email, String? password) {
    registerBackData['email'] = email!;
    registerBackData['password'] = password!;
    setState(() {
      currentPage = AuthPage.login;
    });
  }

  void _logout() async {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    // 儲存目前帳號 email
    final currentEmail = auth.currentAccount != null &&
            auth.currentAccount!.isNotEmpty &&
            !auth.isAnonymous
        ? auth.currentAccount
        : '';
    await auth.logout(context);
    // 把 email 帶回 login 頁
    setState(() {
      registerBackData['email'] = currentEmail!;
      currentPage = AuthPage.login;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = Provider.of<ControllerAuth>(context);
    final localeProvider =
        Provider.of<LocaleProvider>(context); // 獲取 LocaleProvider
    if (auth.isLoading) return Center(child: CircularProgressIndicator());

    Widget bodyWidget;

    // 登入狀態決定 currentPage，不直接改 currentPage，避免 rebuild 問題
    final bool loggedIn = auth.isLoggedIn;

    if (loggedIn) {
      if (currentPage != AuthPage.pageMain) {
        // 如果之前不是pageMain，改成pageMain
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            currentPage = AuthPage.pageMain;
          });
        });
      }
    } else {
      if (currentPage == AuthPage.pageMain) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
          email: registerBackData['email'],
          password: registerBackData['password'],
          onNavigateToRegister: _goToRegister,
        );
        break;

      case AuthPage.register:
        bodyWidget = PageRegister(
          email: registerBackData['email'],
          password: registerBackData['password'],
          onBack: _goBackToLogin,
        );
        break;

      case AuthPage.pageMain:
        bodyWidget = PageMain(
          onPagesChanged: (pages) {
            setState(() {
              _appBarPages = pages;
            });
          },
        );
        break;
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: loc.appTitle,
        currentLocale: localeProvider.locale, // <== 這個很重要
        onLocaleToggle: widget.setLocale,
        account: auth.isLoggedIn ? auth.currentAccount : null,
        onLogout: auth.isLoggedIn ? _logout : null,
        pages: currentPage == AuthPage.pageMain ? _appBarPages : null,  // <== 只有 pageMain 顯示選單
      ),
      body: bodyWidget,
    );
  }
}
