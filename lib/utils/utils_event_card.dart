import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/models/model_event_sub_item.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_date_time.dart' show formatEventDateTime;
import 'package:life_pilot/utils/widget/utils_event_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCardUtils {
  static Widget buildEventHeader({required String title, Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  static Widget buildDateRange({var event}) {
    return Text(
        '${formatEventDateTime(event, constStartToS)}${formatEventDateTime(event, constEndToE)}');
  }

  static Widget buildLocationText({var event}) {
    if (event.city.isEmpty && event.location.isEmpty) return const SizedBox.shrink();
    return Text('${event.city}．${event.location}');
  }

  static Widget buildDescText({var desc}) {
    if (desc.isEmpty) return const SizedBox.shrink();
    return Text('$desc');
  }

  static Widget buildLink(
      {required AppLocalizations loc, required String url}) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        showSnackBar(message: '${loc.url}: $url');
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
    required AppLocalizations loc,
    String? masterUrl,
    required String fee,
    required String type,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (masterUrl?.isNotEmpty == true) buildLink(loc: loc, url: masterUrl!),
        if (desc.isNotEmpty) buildDescText(desc: desc),
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
  List<EventSubItem> get subEvents;
  String get account;
  // 時間相關方法等
}

class BaseEventCard extends StatelessWidget {
  final String tableName;
  final Event event;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showSubEvents;

  const BaseEventCard({
    super.key,
    required this.tableName,
    required this.event,
    this.trailing,
    this.onTap,
    this.onDelete,
    this.showSubEvents = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;

    Widget content = Padding(
      padding: kGapEI4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventCardUtils.buildEventHeader(title: event.name, trailing: trailing),
          if (tableName != constTableRecommendedAttractions)
            EventCardUtils.buildDateRange(event: event),
          if (event.fee.isNotEmpty) widgetBuildTypeTags(types: event.fee),
          if (event.type.isNotEmpty) widgetBuildTypeTags(types: event.type),
          if (event.city.isNotEmpty || event.location.isNotEmpty)
            EventCardUtils.buildLocationText(event: event),
          if ((event.masterUrl != null && event.masterUrl!.isNotEmpty) ||
              event.fee.isNotEmpty ||
              event.type.isNotEmpty ||
              event.description.isNotEmpty)
            EventCardUtils.buildMetaRow(
              loc: loc,
              masterUrl: event.masterUrl != null && event.masterUrl!.isNotEmpty
                  ? event.masterUrl
                  : null,
              fee: event.fee.isNotEmpty ? event.fee : constEmpty,
              type: event.type.isNotEmpty ? event.type : constEmpty,
              desc:
                  event.description.isNotEmpty ? event.description : constEmpty,
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

    Widget container = tableName != constTableCalendarEvents
        ? Card(
            margin: kGapEIH8V16,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          )
        : Container(
            margin: kGapEIH8V16,
            child: content,
          );

    return GestureDetector(
      onTap: event.subEvents.isNotEmpty ? onTap : null,
      child: Stack(
        children: [
          container,
          if ((auth.currentAccount == constSysAdminEmail ||
                  auth.currentAccount == event.account) &&
              onDelete != null)
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
  final EventSubItem subEvent;
  final String parentLocation;

  const _SubEventCard({
    required this.subEvent,
    required this.parentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final showLocation =
        (subEvent.city.isNotEmpty || subEvent.location.isNotEmpty) &&
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
          EventCardUtils.buildDateRange(event: subEvent),
          if (subEvent.fee.isNotEmpty) widgetBuildTypeTags(types: subEvent.fee),
          if (subEvent.type.isNotEmpty) widgetBuildTypeTags(types: subEvent.type),
          if (showLocation) EventCardUtils.buildLocationText(event: subEvent),
          if (subEvent.masterUrl?.isNotEmpty == true)
            EventCardUtils.buildLink(loc: loc, url: subEvent.masterUrl!),
        ],
      ),
    );
  }
}

/// 各種原本的卡片，都改成包裝 BaseEventCard，設定不同參數即可
class EventCard extends StatelessWidget {
  final String tableName;
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCard({
    super.key,
    required this.tableName,
    required this.event,
    required this.index,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      tableName: tableName,
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showSubEvents: true,
    );
  }
}

class EventCardDetail extends StatelessWidget {
  final String tableName;
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCardDetail({
    super.key,
    required this.tableName,
    required this.event,
    required this.index,
    this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      tableName: tableName,
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showSubEvents: false,
    );
  }
}

class EventCalendarCard extends StatelessWidget {
  final String tableName;
  final Event event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCalendarCard({
    super.key,
    required this.tableName,
    required this.event,
    required this.index,
    required this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return BaseEventCard(
      tableName: tableName,
      event: event,
      trailing: trailing,
      onTap: onTap,
      onDelete: onDelete,
      showSubEvents: true,
    );
  }
}

/// 其他原本沒有改動的類別保持不變，例如 EventImageDialog, FullScreenImageViewer
/// 只要確保你在程式中統一使用 BaseEventCard 替代原本重複的卡片實作，就可以有效減少重複代碼。
class EventImageDialog extends StatelessWidget {
  final String tableName;
  final Event event;
  const EventImageDialog(
      {super.key, required this.tableName, required this.event});

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
              tableName: tableName,
              event: event,
              index: 0,
              onTap: () => Navigator.pop(context),
            ),
          ),
          PositionedDirectional(
            end: kGapW8().width,
            top: kGapH8().height,
            child: _buildCloseButton(loc: loc),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton({required AppLocalizations loc}) {
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
        onPressed: () => navigatorKey.currentState?.pop(),
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
