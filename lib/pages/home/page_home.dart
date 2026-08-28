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

        await context.read<ModelDashboard>().refreshAll(
              account: account,
            );
      },
      child: ListView(
        padding: Insets.all12,
        children: [
          TodayScheduleCard(),
          Gaps.h16,
          RecommendEventCard(),
          Gaps.h16,
          RecommendPlaceCard(),
          Gaps.h16,
          IncomeExpenseSummaryCard(),
          Gaps.h16,
          PointSummaryCard(),
        ],
      ),
    );
  }
}
