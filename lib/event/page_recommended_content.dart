import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_base_event.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/event/widgets_event_list.dart';
import 'package:life_pilot/event/widgets_vendor_submission_hub.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:life_pilot/utils/widgets/widgets_search_panel.dart';
import 'package:provider/provider.dart';

enum RecommendedContentKind {
  event,
  attraction;

  String get tableName => switch (this) {
    event => TableNames.recommendEvents,
    attraction => TableNames.recommendPlaces,
  };

  bool get autoRefreshPublicEvents => this == event;

  String emptyText(AppLocalizations loc) => switch (this) {
    event => loc.recommendEventZero,
    attraction => loc.recommendPlacesZero,
  };

  String submitLabel(AppLocalizations loc) => switch (this) {
    event => loc.vendorSubmitActivity,
    attraction => loc.vendorSubmitAttraction,
  };
}

class RecommendedContentPage extends StatefulWidget {
  const RecommendedContentPage({super.key, required this.kind});

  final RecommendedContentKind kind;

  @override
  State<RecommendedContentPage> createState() => _RecommendedContentPageState();
}

class _RecommendedContentPageState extends State<RecommendedContentPage> {
  late final ControllerEvent _controllerEvent;
  bool _showOnlyMySubmissions = false;

  @override
  void initState() {
    super.initState();
    _controllerEvent = ControllerEvent(
      auth: context.read<ControllerAuth>(),
      serviceEvent: context.read<ServiceEvent>(),
      serviceWeather: context.read<ServiceWeather>(),
      tableName: widget.kind.tableName,
      toTableName: TableNames.calendarEvents,
      modelEvent: ModelEvent(),
    );
  }

  @override
  void dispose() {
    _controllerEvent.dispose();
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

  Widget _buildSubmissionHub(BuildContext context, {required bool isVendor}) {
    final loc = AppLocalizations.of(context)!;
    return VendorSubmissionHub(
      submitLabel: widget.kind.submitLabel(loc),
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

    return ChangeNotifierProvider.value(
      value: _controllerEvent,
      child: GenericEventPage(
        auth: auth,
        controllerEvent: _controllerEvent,
        title: '',
        emptyText: widget.kind.emptyText(loc),
        enableCityFilter: true,
        searchPanelBuilder: widgetsSearchPanel,
        headerBuilder: (context) =>
            _buildSubmissionHub(context, isVendor: isVendor),
        showAddAction: false,
        autoRefreshPublicEvents: widget.kind.autoRefreshPublicEvents,
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
            }) => WidgetsEventList(
              filteredEvents: filteredEvents,
              scrollController: scrollController,
              controllerEvent: _controllerEvent,
              auth: auth,
            ),
      ),
    );
  }
}
