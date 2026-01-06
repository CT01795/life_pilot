import 'package:flutter/material.dart';
import 'package:life_pilot/config/config_app.dart';
import 'package:life_pilot/core/app_navigator.dart' as app_navigator;
import 'package:life_pilot/core/theme.dart';
import 'package:life_pilot/pages/auth/page_auth_check.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:provider/provider.dart';

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {  
  @override
  void initState() {
    super.initState();
    // ✅ 僅初始化一次全域錯誤處理
    app_navigator.AppNavigator.initErrorHandling();
  }

  @override
  Widget build(BuildContext context) {
    //final localeProvider = context.watch<ProviderLocale>();
    // ✅ 只監聽 locale，不重建整個 MaterialApp
    return RepaintBoundary(
      key: app_navigator.rootRepaintBoundaryKey, // 🌟 全局 RepaintBoundary
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
              // ⚙️ 允許自動調整但限制最大字體放大倍率
              final mediaQuery = MediaQuery.of(context);

              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: TextScaler.linear(1.5)),
                child: child ?? const SizedBox.shrink(), //避免 child 為 null 時 crash，防禦性寫法。
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

// ✅ 把 home 包出去，減少 rebuild 開銷
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

/*🚀 優化重點解析

Selector 取代 watch
只讓語言（locale）變化時重建 MaterialApp
其他 Provider 更新（例如登入狀態、主題等）不會觸發整個 app rebuild
🔹大幅降低 rebuild 成本。

初始化搬出 build()
initErrorHandling() 應該只初始化一次，放在 initState() 最乾淨。

child ?? SizedBox.shrink()
避免 child 為 null 時 crash，防禦性寫法。

_AppHome 分離
當語言切換時，只有 MaterialApp rebuild，
而 PageAuthCheck 不會整個重新建立，保留內部狀態（例如登入檢查結果）。*/
