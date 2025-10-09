import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_zh.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_calendar.dart';
import 'package:life_pilot/pages/specific/page_memory_trace.dart';
import 'package:life_pilot/pages/specific/page_recommended_attractions.dart';
import 'package:life_pilot/pages/specific/page_recommended_event.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/providers/provider.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  const PageMain({super.key});

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  late ControllerPageMain _controller;
  late Map<PageType, WidgetBuilder> _pageMap;
  bool _controllerInitialized = false;

  @override
  void initState() {
    super.initState();

    final auth = getIt<ControllerAuth>();
    _controller = ControllerPageMain(
      auth: auth,
      loc: AppLocalizationsZh(), // 先給預設值，避免 late 初始化失敗
    );

    _pageMap = {
      PageType.personalEvent: (_) => const PageCalendar(),
      PageType.settings: (_) => const PageA(),
      PageType.recommendedEvent: (_) => PageRecommendedEvent(),
      PageType.recommendedAttractions: (_) => PageRecommendedAttractions(),
      PageType.memoryTrace: (_) => const PageMemoryTrace(),
      PageType.accountRecords: (_) => const PageA(),
      PageType.pointsRecord: (_) => const PageA(),
      PageType.game: (_) => const PageA(),
      PageType.ai: (_) => const PageA(),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    if (!_controllerInitialized) {
      _controllerInitialized = true;
      _controller.loc = loc;
      _controller.init(locale: locale);
    } else {
      _controller.onLocaleChanged(newLoc: loc, newLocale: locale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ControllerPageMain>(
        builder: (_, controller, __) {
          final selectedBuilder = _pageMap[controller.selectedPage];
          return selectedBuilder != null
              ? Padding(
                  padding: kGapEIL1R1T8B1,
                  child: selectedBuilder(context),
                )
              : const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  @override
  void dispose() {
    // ✅ 清空 appBarWidgets 避免殘留
    appBarWidgetsProvider.value = [];
    _controller.dispose();
    super.dispose();
  }
}
