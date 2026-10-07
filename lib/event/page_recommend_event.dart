import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_base_event.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/widgets/widgets_search_panel.dart';
import 'package:provider/provider.dart';

import 'widgets_event_list.dart';
import 'widgets_vendor_submission_hub.dart';

class PageRecommendEvent extends StatefulWidget {
  const PageRecommendEvent({super.key});

  @override
  State<PageRecommendEvent> createState() => _PageRecommendEventState();
}

class _PageRecommendEventState extends State<PageRecommendEvent> {
  late final ControllerEvent _controllerEvent;
  bool _showOnlyMySubmissions = false;

  @override
  void initState() {
    super.initState();
    final context = this.context; // ✅ 避免多次 lookup

    _controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: TableNames.recommendEvents,
      toTableName: TableNames.calendarEvents,
      modelEvent: ModelEvent(),
    );
  }

  @override
  void dispose() {
    _controllerEvent.dispose(); // ✅ 確保釋放資源
    super.dispose();
  }

  Future<void> _openSubmissionForm() async {
    final event = await Navigator.of(context).push<EventItem?>(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(controllerEvent: _controllerEvent),
      ),
    );
    if (event == null || !mounted) return;
    await context.read<ControllerAuth>().refreshSubscriptionUsage();
    await _controllerEvent.loadEvents(isGetPublicEvents: false);
  }

  Widget _buildVendorSubmissionHub(
    BuildContext context, {
    required bool isVendor,
  }) {
    final loc = AppLocalizations.of(context)!;
    return VendorSubmissionHub(
      submitLabel: loc.vendorSubmitActivity,
      showOnlyMySubmissions: _showOnlyMySubmissions,
      showSubmissionFilter: !isVendor,
      onSubmit: _openSubmissionForm,
      onFilterChanged: (selected) {
        setState(() => _showOnlyMySubmissions = selected);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.read<ControllerAuth>();
    final isVendor = context.select<ControllerAuth, bool>(
      (controller) => controller.isVendor,
    );
    final currentAccount = context.select<ControllerAuth, String?>(
      (controller) => controller.currentAccount,
    );
    // ✅ 回傳 Provider Scope，包住整個頁面
    return ChangeNotifierProvider.value(
      value: _controllerEvent,
      child: GenericEventPage(
        auth: auth,
        controllerEvent: _controllerEvent,
        title: '',
        emptyText: loc.recommendEventZero,
        enableCityFilter: true,
        searchPanelBuilder: widgetsSearchPanel,
        headerBuilder: (context) =>
            _buildVendorSubmissionHub(context, isVendor: isVendor),
        showAddAction: false,
        autoRefreshPublicEvents: true,
        eventPredicate: isVendor || _showOnlyMySubmissions
            ? (event) => shouldShowSubmission(
                isVendor: isVendor,
                showOnlyMySubmissions: _showOnlyMySubmissions,
                submissionAccount: event.account,
                currentAccount: currentAccount,
              )
            : null,
        listBuilder:
            ({
              required List<EventItem> filteredEvents,
              required ScrollController scrollController,
            }) {
              return WidgetsEventList(
                filteredEvents: filteredEvents,
                scrollController: scrollController,
                controllerEvent: _controllerEvent,
                auth: auth,
              );
            },
      ),
    );
  }
}
