import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/business_plan/page_business_plan.dart';
import 'package:life_pilot/accounting/page_accounting_list.dart';
import 'package:life_pilot/pages/home/page_home.dart';
import 'package:life_pilot/stock/page_stock.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/apps/page_ai.dart';
import 'package:life_pilot/calendar/page_calendar.dart';
import 'package:life_pilot/memory_trace/page_memory_trace.dart';
import 'package:life_pilot/event/page_recommended_attractions.dart';
import 'package:life_pilot/event/page_recommend_event.dart';
import 'package:life_pilot/game/page_game_list.dart';
import 'package:life_pilot/feedback/page_feedback_admin.dart';
import 'package:life_pilot/point_record/page_point_record.dart';
import 'package:life_pilot/apps/page_settings.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  const PageMain({super.key});

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  final Map<PageType, Widget> _pageMap = {};

  Widget _getPage(PageType type) {
    return _pageMap.putIfAbsent(
      type,
      () => _buildPage(type),
    );
  }

  Widget _buildPage(PageType type) => switch (type) {
    PageType.home => const PageHome(),
    PageType.personalEvent => const PageCalendar(),
    PageType.stock => const PageStock(),
    PageType.settings => const PageSettings(),
    PageType.recommendEvent => const PageRecommendEvent(),
    PageType.recommendPlaces => const PageRecommendPlaces(),
    PageType.memoryTrace => const PageMemoryTrace(),
    PageType.accountRecords => const PageAccountingList(),
    PageType.pointsRecord => const PagePointRecord(),
    PageType.game => const PageGameList(),
    PageType.ai => const PageAI(),
    PageType.feedbackAdmin => const PageFeedbackAdmin(),
    PageType.businessPlan => const PageBusinessPlan(),
  };
  
  @override
  Widget build(BuildContext context) {
    final selectedPage = context.select<ControllerPageMain, PageType>(
      (controller) => controller.selectedPage,
    );

    return _getPage(selectedPage);
  }
}
