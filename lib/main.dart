import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/pages/page_register.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/utils/utils_class_main_page_bar.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/controller_auth.dart';
import 'l10n/app_localizations.dart';
import 'pages/page_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
            create: (_) => ProviderLocale(locale: Locale('zh'))),  
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
        title: 'Life Pilot',
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
          Locale('en'),
          Locale('zh'),
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
  Map<String, String> registerBackData = {'email': '', 'password': ''};
  List<Widget> _appBarPages = [];

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
    final currentEmail = auth.currentAccount != null &&
            auth.currentAccount!.isNotEmpty &&
            !auth.isAnonymous
        ? auth.currentAccount
        : '';
    await auth.logout(context);
    setState(() {
      registerBackData['email'] = currentEmail!;
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _appBarPages = pages;
                });
              }
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
