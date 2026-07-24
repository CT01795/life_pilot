import 'package:flutter/material.dart';
import 'package:life_pilot/auth/auth_gate.dart';
import 'package:life_pilot/pages/home/widgets/page_selector_dropdown.dart';
import 'package:life_pilot/pages/home/widgets/user_menu_button.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/utils/service/service_startup.dart';
import 'package:life_pilot/utils/widgets/widgets_language_toggle_dropdown.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StartupService.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ModelAuthView, bool>(
      selector: (_, auth) => auth.isLoading,
      builder: (_, loading, __) {
        if (loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const AuthGate();
      },
    );
  }
}

class MainPageBar extends StatelessWidget implements PreferredSizeWidget {
  const MainPageBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ModelAuthView>();
    final loc = AppLocalizations.of(context)!;
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      title: Text(
        (auth.account?.isNotEmpty ?? false) ? '' : loc.appTitle,
      ),
      flexibleSpace: SafeArea(
        child: Row(
          children: [
            // 左側 Page Selector
            if (auth.account?.isNotEmpty ?? false)
              Padding(
                padding: Insets.l8,
                child: Tooltip(
                  message: loc.pageSelectorTooltip,
                  child: const PageSelectorDropdown(),
                ),
              ),

            const Spacer(),

            // 右側 Language
            Tooltip(
              message: loc.language,
              child: LanguageToggleDropdown(),
            ),
            Gaps.w16,
            // 右側 User
            UserMenuButton(),
            Gaps.w8,
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
