import 'package:flutter/material.dart';
import 'package:life_pilot/auth/auth_gate.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/widgets/page_selector_dropdown.dart';
import 'package:life_pilot/pages/home/widgets/user_menu_button.dart';
import 'package:life_pilot/utils/const.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await StartupService.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<ModelAuthView, bool>(
      selector: (_, auth) => auth.isLoading,
      builder: (_, loading, _) {
        if (loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return const AuthGate();
      },
    );
  }
}

class MainPageBar extends StatelessWidget implements PreferredSizeWidget {
  const MainPageBar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ModelAuthView>();
    final loc = AppLocalizations.of(context)!;
    final isSignedIn = auth.account?.isNotEmpty ?? false;
    final useCompactActions = MediaQuery.sizeOf(context).width < 520;

    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      titleSpacing: 8,
      title: isSignedIn
          ? Tooltip(
              message: loc.pageSelectorTooltip,
              child: const PageSelectorDropdown(),
            )
          : Text(loc.appTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        Tooltip(
          message: loc.language,
          child: LanguageToggleDropdown(compact: useCompactActions),
        ),
        Gaps.w8,
        const SizedBox(width: 52, child: UserMenuButton()),
        Gaps.w8,
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
