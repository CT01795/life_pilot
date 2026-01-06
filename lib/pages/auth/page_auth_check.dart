import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/controller_feedback.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/auth/model_auth_view.dart';
import 'package:life_pilot/pages/auth/page_login.dart';
import 'package:life_pilot/pages/auth/page_register.dart';
import 'package:life_pilot/pages/page_feedback.dart';
import 'package:life_pilot/pages/page_main.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/services/service_feedback.dart';
import 'package:life_pilot/views/widgets/widgets_language_toggle_dropdown.dart';
import 'package:provider/provider.dart';

class PageAuthCheck extends StatefulWidget {
  final Function(Locale) setLocale;
  const PageAuthCheck({super.key, required this.setLocale});

  @override
  State<PageAuthCheck> createState() => _PageAuthCheckState();
}

class _PageAuthCheckState extends State<PageAuthCheck> {
  @override
  void initState() {
    super.initState();
    // ✅ 延後檢查登入狀態，避免在 build 階段觸發 notifyListeners()
    // 避免在 build() 或 didChangeDependencies() 內做 setState() 或 notifyListeners()。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ModelAuthView>().checkLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 最外層監聽語言變化
    return Consumer<ProviderLocale>(builder: (context, localeProvider, _) {
      final loc = AppLocalizations.of(context)!;

      // ✅ 內層只監聽 isLoading
      return Selector<ModelAuthView, bool>(
        selector: (_, model) => model.isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // ✅ 登入完成後再監聽登入資訊與頁面切換
          return Consumer<ModelAuthView>(
            builder: (context, modelAuthView, _) {
              return Scaffold(
                appBar: MainPageBar(
                  title: loc.appTitle,
                  currentLocale: localeProvider.locale,
                  account: modelAuthView.account,
                  onLogout: modelAuthView.logout,
                ),
                body: _AuthBodySwitcher(loc),
              );
            },
          );
        },
      );
    });
  }
}

//負責顯示對應頁面（Login / Register / Main）
class _AuthBodySwitcher extends StatelessWidget {
  final AppLocalizations loc;
  const _AuthBodySwitcher(this.loc);

  @override
  Widget build(BuildContext context) {
    return Selector<ModelAuthView, AuthPage>(
      selector: (_, model) => model.currentPage,
      builder: (context, currentPage, _) {
        final auth = context.read<ModelAuthView>();
        switch (currentPage) {
          case AuthPage.login:
            return PageLogin(
              email: auth.getRegisterEmail(),
              password: auth.getRegisterPassword(),
              onNavigateToRegister: (email, password) =>
                  auth.goToRegister(email, password),
            );

          case AuthPage.register:
            return PageRegister(
              email: auth.getRegisterEmail(),
              password: auth.getRegisterPassword(),
              onBack: (email, password) => auth.goBackToLogin(email, password),
            );

          case AuthPage.pageMain:
            return const PageMain();
        }
      },
    );
  }
}

class MainPageBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Locale currentLocale;
  final String? account;
  final VoidCallback? onLogout;

  const MainPageBar({
    super.key,
    required this.title,
    required this.currentLocale,
    this.account,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.primaryColor,
      iconTheme: theme.iconTheme,
      title: Text(
        (account?.contains('@') ?? false)
            ? account!.split('@')[0]
            : account ?? title,
      ),
      actions: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((account != null && account!.isNotEmpty))
              Consumer<ControllerPageMain>(
                builder: (context, controller, _) {
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<PageType>(
                      value: controller.availablePages
                              .contains(controller.selectedPage)
                          ? controller.selectedPage
                          : controller.availablePages.first, // ✅ fallback 避免錯誤
                      style: const TextStyle(color: Colors.white),
                      dropdownColor: const Color(0xFF0066CC),
                      iconEnabledColor: Colors.white,
                      items: controller.availablePages.map((page) {
                        return DropdownMenuItem(
                          value: page,
                          child: Text(page.title(loc: loc)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) controller.changePage(value);
                      },
                    ),
                  );
                },
              ),
            LanguageToggleDropdown(
              currentLocale: currentLocale,
            ),
            IconButton(
              icon: const Icon(Icons.feedback, color: Colors.white),
              tooltip: 'Feedback',
              onPressed: () {
                final screenSize = MediaQuery.of(context).size;
                double width = screenSize.width / 2;
                double height = screenSize.height * 0.8;
                double top = 50;
                double left = screenSize.width / 2 - 20;

                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) {
                    return StatefulBuilder(builder: (context, setState) {
                      return Stack(
                        children: [
                          // 背景半透明，點擊可以關閉
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              color: Colors.black54,
                            ),
                          ),

                          // 可拖動視窗
                          Positioned(
                            top: top,
                            left: left,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                setState(() {
                                  top += details.delta.dy;
                                  left += details.delta.dx;

                                  // 邊界限制
                                  if (top < 0) top = 0;
                                  if (left < 0) left = 0;
                                  if (top + height > screenSize.height) {
                                    top = screenSize.height - height;
                                  }
                                  if (left + width > screenSize.width) {
                                    left = screenSize.width - width;
                                  }
                                });
                              },
                              child: Container(
                                width: width,
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // 標題列
                                    Container(
                                      height: 40,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Feedback',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.white),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                          )
                                        ],
                                      ),
                                    ),

                                    // 內容區 + 右下角縮放手把
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: ChangeNotifierProvider(
                                              create: (_) => ControllerFeedback(
                                                ServiceFeedback(),
                                                context.read<ControllerAuth>(),
                                              ),
                                              child: const PageFeedbackBody(),
                                            ),
                                          ),

                                          // 右下角縮放手把
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: GestureDetector(
                                              onPanUpdate: (details) {
                                                setState(() {
                                                  width += details.delta.dx;
                                                  height += details.delta.dy;

                                                  // 最小限制
                                                  if (width < 300) width = 300;
                                                  if (height < 400) {
                                                    height = 400;
                                                  }

                                                  // 最大限制
                                                  if (width > screenSize.width) {
                                                    width = screenSize.width;
                                                  }
                                                  if (height >
                                                      screenSize.height) {
                                                    height = screenSize.height;
                                                  }
                                                });
                                              },
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Icon(
                                                    Icons.drag_handle,
                                                    size: 16,
                                                    color: Colors.white),
                                              ),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    });
                  },
                );
              },
            ),
            if ((account != null && account!.isNotEmpty))
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                tooltip: loc.logout,
                color: Colors.white,
                onPressed: onLogout,
              ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
