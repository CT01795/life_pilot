import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_calendar.dart';
import 'package:life_pilot/pages/event/page_memory_trace.dart';
import 'package:life_pilot/pages/event/page_recommended_attractions.dart';
import 'package:life_pilot/pages/event/page_recommended_event.dart';
import 'package:life_pilot/pages/page_game_list.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  const PageMain({super.key});

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  final Map<PageType, Widget> _pageMap = {};
  PageType? _currentPage;

  Widget _getPage(PageType type) {
    if (!_pageMap.containsKey(type)) {
      _pageMap[type] = _buildPage(type); // 延後建立
    }
    return _pageMap[type]!;
  }

  Widget _buildPage(PageType type) {
    switch (type) {
      case PageType.personalEvent:
        return const PageCalendar();
      case PageType.settings:
        return const PageA();
      case PageType.recommendedEvent:
        return const PageRecommendedEvent();
      case PageType.recommendedAttractions:
        return const PageRecommendedAttractions();
      case PageType.memoryTrace:
        return const PageMemoryTrace();
      case PageType.accountRecords:
        return const PageA();
      case PageType.pointsRecord:
        return const PageA();
      case PageType.game:
        return const PageGameList();
      case PageType.ai:
        return const PageA();
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = context.select<ControllerPageMain, PageType>(
      (controller) => controller.selectedPage,
    );
    _currentPage = selectedPage;

    return IndexedStack(
      index: 0, // 只顯示當前頁面
      children: [_getPage(_currentPage!)],
    );
  }
}
