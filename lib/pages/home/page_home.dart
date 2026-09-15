import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/income_expense_summary_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/point_summary_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommend_event_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommend_place_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/today_schedule_card.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageHome extends StatefulWidget {
  const PageHome({super.key});

  @override
  State<PageHome> createState() => _PageHomeState();
}

class _PageHomeState extends State<PageHome> {
  bool _recommendEventsExpanded = false;
  bool _recommendPlacesExpanded = false;
  bool _accountingExpanded = false;
  bool _pointsExpanded = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final account = context.read<ModelAuthView>().account;
      final dashboard = context.read<ModelDashboard>();

      if (account == null || account.isEmpty) return;

      await Future.wait<void>([
        dashboard.loadEventCities(account),
        dashboard.loadPlaceCities(account),
        dashboard.refreshAll(account: account),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final account = context.read<ModelAuthView>().account;

        if (account == null || account.isEmpty) {
          return;
        }

        final dashboard = context.read<ModelDashboard>();
        await Future.wait<void>([
          dashboard.loadEventCities(account, forceRefresh: true),
          dashboard.loadPlaceCities(account, forceRefresh: true),
          dashboard.refreshAll(account: account),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: Insets.all12,
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TodayScheduleCard(),
                  Gaps.h16,
                  RecommendEventCard(
                    isExpanded: _recommendEventsExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _recommendEventsExpanded = value),
                  ),
                  Gaps.h16,
                  RecommendPlaceCard(
                    isExpanded: _recommendPlacesExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _recommendPlacesExpanded = value),
                  ),
                  Gaps.h16,
                  IncomeExpenseSummaryCard(
                    isExpanded: _accountingExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _accountingExpanded = value),
                  ),
                  Gaps.h16,
                  PointSummaryCard(
                    isExpanded: _pointsExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _pointsExpanded = value),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
