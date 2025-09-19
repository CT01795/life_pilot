import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart' show formatEventDateTime;
import 'package:life_pilot/utils/utils_event_widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCardUtils {
  static Widget buildEventHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  static Widget buildDateRange(var e) {
    return Text('${formatEventDateTime(e, constStartToS)}${formatEventDateTime(e, constEndToE)}');
  }

  static Widget buildLocationText(var e) {
    if (e.city.isEmpty && e.location.isEmpty) return const SizedBox.shrink();
    return Text('${e.city}．${e.location}');
  }

  static Widget buildLink(BuildContext context, AppLocalizations loc, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        showSnackBar(context, '${loc.url}: $url');
      },
      child: Text(
        loc.click_here_to_see_more,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  static Widget buildMetaRow({
    required BuildContext context,
    required AppLocalizations loc,
    String? masterUrl,
    required String fee,
    required String type,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (masterUrl?.isNotEmpty == true) buildLink(context, loc, masterUrl!),
        /*kGapW8(),
        if (fee.isNotEmpty)
          Padding(
            padding: kGapEIT4,
            child: widgetBuildTypeTags(fee),
          ),
        kGapW8(),
        if (type.isNotEmpty)
          Padding(
            padding: kGapEIT4,
            child: widgetBuildTypeTags(type),
          ),*/
      ],
    );
  }
}

/// 共用的事件基底類別接口，方便型別使用
abstract class EventBase {
  String get name;
  String get fee;
  String get type;
  String get city;
  String get location;
  String? get masterUrl;
  List<SubEventItem> get subEvents;
  String get account;
  // 時間相關方法等
}

class BaseEventCard extends StatelessWidget {
  final Event event;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showLocation;
  final bool showFeeType;
  final bool showSubEvents;
  final bool showMasterUrlLink;
  final bool useCardContainer;

  const BaseEventCard({
    super.key,
    required this.event,
    this.trailing,
    this.onTap,
    this.onDelete,
    this.showLocation = true,
    this.showFeeType = true,
    this.showSubEvents = true,
    this.showMasterUrlLink = true,
    this.useCardContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<ControllerAuth>(context,listen:false);
    final loc = AppLocalizations.of(context)!;

    Widget content = Padding(
      padding: kGapEI4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventCardUtils.buildEventHeader(event.name, trailing: trailing),
          EventCardUtils.buildDateRange(event),
          if (showFeeType && event.fee.isNotEmpty) widgetBuildTypeTags(event.fee),
          if (showFeeType && event.type.isNotEmpty) widgetBuildTypeTags(event.type),
          if (showLocation && (event.city.isNotEmpty || event.location.isNotEmpty))
            EventCardUtils.buildLocationText(event),
          if (showMasterUrlLink || showFeeType)
            EventCardUtils.buildMetaRow(
              context: context,
              loc: loc,
              masterUrl: showMasterUrlLink ? event.masterUrl : null,
              fee: showFeeType ? event.fee : constEmpty,
              type: showFeeType ? event.type : constEmpty,
            ),
          if (showSubEvents)
            ...event.subEvents.map(
              (sub) => _SubEventCard(
                parentLocation: event.location,
                subEvent: sub,
              ),
            ),
        ],
      ),
    );

    Widget container = useCardContainer
        ? Card(
            margin: kGapEIH8V16,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          )
        : Container(
            margin: kGapEIH8V16,
            child: content,
          );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          container,
          if (auth.currentAccount == event.account && onDelete != null)
            PositionedDirectional(
              end: kGapW24().width,
              bottom: kGapH8().height, //bottom
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                tooltip: loc.delete,
                onPressed: onDelete,
              ),
            ),
        ],
      ),
    );
  }
}

class _SubEventCard extends StatelessWidget {
  final SubEventItem subEvent;
  final String parentLocation;

  const _SubEventCard({
    required this.subEvent,
    required this.parentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final showLocation = (subEvent.city.isNotEmpty || subEvent.location.isNotEmpty) &&
        subEvent.location != parentLocation;

    return Container(
      width: double.infinity,
      margin: kGapEIL20R0T6B0,
      padding: kGapEI4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "👉 ${subEvent.name}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          EventCardUtils.buildDateRange(subEvent),
          if(subEvent.fee.isNotEmpty) widgetBuildTypeTags(subEvent.fee),
          if(subEvent.type.isNotEmpty) widgetBuildTypeTags(subEvent.type),
          if (showLocation) EventCardUtils.buildLocationText(subEvent),
          if (subEvent.masterUrl?.isNotEmpty == true)
            EventCardUtils.buildLink(context, loc, subEvent.masterUrl!),
        ],
      ),
    );
  }
}

/// 各種原本的卡片，都改成包裝 BaseEventCard，設定不同參數即可

class EventCard extends StatelessWidget {
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCard({
    super.key,
    required this.event,
    required this.index,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showLocation: true,
      showFeeType: true,
      showSubEvents: true,
      showMasterUrlLink: true,
      useCardContainer: true,
    );
  }
}

class EventCardGraph extends StatelessWidget {
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCardGraph({
    super.key,
    required this.event,
    required this.index,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showLocation: true,
      showFeeType: true,
      showSubEvents: false,
      showMasterUrlLink: true,
      useCardContainer: true,
    );
  }
}

class EventCalendarCard extends StatelessWidget {
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCalendarCard({
    super.key,
    required this.event,
    required this.index,
    required this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showLocation: true,
      showFeeType: true,
      showSubEvents: true,
      showMasterUrlLink: true,
      useCardContainer: false,
    );
  }
}

/// 其他原本沒有改動的類別保持不變，例如 EventImageDialog, FullScreenImageViewer
/// 只要確保你在程式中統一使用 BaseEventCard 替代原本重複的卡片實作，就可以有效減少重複代碼。

class EventImageDialog extends StatelessWidget {
  final Event event;
  const EventImageDialog({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kGapEIH6,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: EventCard(
              event: event,
              index: 0,
              onTap: () => Navigator.pop(context),
            ),
          ),
          PositionedDirectional(
            end: kGapW8().width,
            top: kGapH8().height,
            child: _buildCloseButton(context, loc),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(BuildContext context, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.close),
        tooltip: loc.close,
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final displayUrl = imageUrl.replaceFirst('dl=0', 'raw=1');
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.network(displayUrl, fit: BoxFit.contain),
        ),
      ),
    );
  }
}