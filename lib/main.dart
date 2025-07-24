import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/pages/page_recommended_event.dart';

import 'pages/page_login.dart';
import 'services/service_auth.dart';
//import 'modules/settings/settings_page.dart';
//import 'modules/recommended_event/recommended_event_page.dart';

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

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 用於存儲當前語言的變數
  Locale _locale = Locale('zh'); // 默認設置為英文

  // 切換語言的方法
  void _setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
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
      locale: _locale, // 設置當前語言
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: AuthCheckPage(setLocale: _setLocale),
    );
  }
}

class AuthCheckPage extends StatefulWidget {
  const AuthCheckPage({super.key, required this.setLocale});
  final Function(Locale) setLocale;

  @override
  // ignore: library_private_types_in_public_api
  _AuthCheckPageState createState() => _AuthCheckPageState();
}

class _AuthCheckPageState extends State<AuthCheckPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    setState(() {
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return CircularProgressIndicator();

    return Scaffold(
      appBar: AppBar(
        title: Text('Life Pilot'),
        actions: [
          // 語言切換按鈕
          IconButton(
            icon: Icon(Icons.language),
            onPressed: () {
              // 切換語言
              if (Localizations.localeOf(context).languageCode == 'en') {
                widget.setLocale(Locale('zh'));
              } else {
                widget.setLocale(Locale('en'));
              }
            },
          ),
        ],
      ),
      body: _isLoggedIn ? PageRecommendedEvent() : PageLogin(email: ''),
    );
  }
}
