import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/income_expense_summary_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/point_summary_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommend_event_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/recommend_place_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/today_schedule_card.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/today_life_overview_card.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageHome extends StatefulWidget {
  const PageHome({super.key});

  @override
  State<PageHome> createState() => _PageHomeState();
}

class _PageHomeState extends State<PageHome> {
  final _scheduleKey = GlobalKey();
  final _accountingKey = GlobalKey();
  final _pointsKey = GlobalKey();
  bool _todayScheduleExpanded = true;
  bool _recommendEventsExpanded = false;
  bool _recommendPlacesExpanded = false;
  bool _accountingExpanded = false;
  bool _pointsExpanded = false;
  Future<void>? _coreLoad;
  String? _coreAccount;
  Future<void>? _recommendEventsLoad;
  Future<void>? _recommendPlacesLoad;
  String? _recommendEventsAccount;
  String? _recommendPlacesAccount;

  void _openSection(GlobalKey key, VoidCallback expand) {
    setState(expand);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = key.currentContext;
      if (!mounted || targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final account = context.read<ModelAuthView>().account;
      final dashboard = context.read<ModelDashboard>();

      if (account == null || account.isEmpty) return;

      final operation = dashboard.refreshCore(account: account);
      _coreAccount = account;
      _coreLoad = operation;
      await operation;
    });
  }

  Future<void> _ensureRecommendEvents({bool forceRefresh = false}) async {
    final account = context.read<ModelAuthView>().account;
    if (account == null || account.isEmpty) return;
    if (_coreAccount == account) await _coreLoad;
    if (!mounted || context.read<ModelAuthView>().account != account) return;
    if (_recommendEventsAccount != account) {
      _recommendEventsAccount = account;
      _recommendEventsLoad = null;
    }
    if (_recommendEventsLoad != null && !forceRefresh) {
      return _recommendEventsLoad;
    }
    final dashboard = context.read<ModelDashboard>();
    final operation = Future.wait<void>([
      dashboard.loadEventCities(account, forceRefresh: forceRefresh),
      dashboard.retrySection(
        section: DashboardSection.recommendEvents,
        account: account,
      ),
    ]);
    _recommendEventsLoad = operation;
    if (mounted) setState(() {});
    await operation;
  }

  Future<void> _ensureRecommendPlaces({bool forceRefresh = false}) async {
    final account = context.read<ModelAuthView>().account;
    if (account == null || account.isEmpty) return;
    if (_coreAccount == account) await _coreLoad;
    if (!mounted || context.read<ModelAuthView>().account != account) return;
    if (_recommendPlacesAccount != account) {
      _recommendPlacesAccount = account;
      _recommendPlacesLoad = null;
    }
    if (_recommendPlacesLoad != null && !forceRefresh) {
      return _recommendPlacesLoad;
    }
    final dashboard = context.read<ModelDashboard>();
    final operation = Future.wait<void>([
      dashboard.loadPlaceCities(account, forceRefresh: forceRefresh),
      dashboard.retrySection(
        section: DashboardSection.recommendPlaces,
        account: account,
      ),
    ]);
    _recommendPlacesLoad = operation;
    if (mounted) setState(() {});
    await operation;
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
        final coreOperation = dashboard.refreshCore(account: account);
        _coreAccount = account;
        _coreLoad = coreOperation;
        await coreOperation;
        await Future.wait<void>([
          if (_recommendEventsLoad != null)
            _ensureRecommendEvents(forceRefresh: true),
          if (_recommendPlacesLoad != null)
            _ensureRecommendPlaces(forceRefresh: true),
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
                  TodayLifeOverviewCard(
                    onSchedulePressed: () => _openSection(
                      _scheduleKey,
                      () => _todayScheduleExpanded = true,
                    ),
                    onAccountingPressed: () => _openSection(
                      _accountingKey,
                      () => _accountingExpanded = true,
                    ),
                    onPointsPressed: () =>
                        _openSection(_pointsKey, () => _pointsExpanded = true),
                  ),
                  Gaps.h16,
                  TodayScheduleCard(
                    key: _scheduleKey,
                    isExpanded: _todayScheduleExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _todayScheduleExpanded = value),
                  ),
                  Gaps.h16,
                  RecommendEventCard(
                    isExpanded: _recommendEventsExpanded,
                    hasRequestedData: _recommendEventsLoad != null,
                    onExpansionChanged: (value) {
                      setState(() => _recommendEventsExpanded = value);
                      if (value) unawaited(_ensureRecommendEvents());
                    },
                  ),
                  Gaps.h16,
                  RecommendPlaceCard(
                    isExpanded: _recommendPlacesExpanded,
                    hasRequestedData: _recommendPlacesLoad != null,
                    onExpansionChanged: (value) {
                      setState(() => _recommendPlacesExpanded = value);
                      if (value) unawaited(_ensureRecommendPlaces());
                    },
                  ),
                  Gaps.h16,
                  IncomeExpenseSummaryCard(
                    key: _accountingKey,
                    isExpanded: _accountingExpanded,
                    onExpansionChanged: (value) =>
                        setState(() => _accountingExpanded = value),
                  ),
                  Gaps.h16,
                  PointSummaryCard(
                    key: _pointsKey,
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
