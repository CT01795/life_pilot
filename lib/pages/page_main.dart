import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_calendar.dart';
import 'package:life_pilot/pages/event/page_memory_trace.dart';
import 'package:life_pilot/pages/event/page_recommended_attractions.dart';
import 'package:life_pilot/pages/event/page_recommended_event.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  const PageMain({super.key});

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  late final Map<PageType, Widget> _pageMap;
  late final List<PageType> _pageKeys;

  @override
  void initState() {
    super.initState();
    _pageMap = {
      PageType.personalEvent: const PageCalendar(),
      PageType.settings: const PageA(),
      PageType.recommendedEvent: const PageRecommendedEvent(),
      PageType.recommendedAttractions: const PageRecommendedAttractions(),
      PageType.memoryTrace: const PageMemoryTrace(),
      PageType.accountRecords: const PageA(),
      PageType.pointsRecord: const PageA(),
      PageType.game: const PageA(),
      PageType.ai: const PageA(),
    };
    _pageKeys = _pageMap.keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedPage = context.select<ControllerPageMain, PageType>(
      (controller) => controller.selectedPage,
    );

    return IndexedStack(
      index: _pageKeys.indexOf(selectedPage),
      children: _pageMap.values.toList(),
    );
  }
}
