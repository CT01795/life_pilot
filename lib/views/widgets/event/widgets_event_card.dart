// lib/views/widgets/event/event_card_widgets.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_sub_card.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetsEventCard extends StatelessWidget {

  final String tableName;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;
  final bool showSubEvents;
  final EventController eventController;

  const WidgetsEventCard({
    super.key,
    required this.tableName,
    required this.index,
    required this.eventController,
    this.onTap,
    this.onDelete,
    this.trailing,
    this.showSubEvents = true, // 設定預設值為 true
  });

  @override
  Widget build(BuildContext context) {
    final auth = getIt<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;
    final content = Padding(
      padding: kGapEI4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WidgetsEventCard.header(title: eventController.name, trailing: trailing),
          if (tableName != constTableRecommendedAttractions)
            Text(eventController.dateRange),
          if (eventController.fee.isNotEmpty) tags(types: eventController.fee),
          if (eventController.type.isNotEmpty) tags(types: eventController.type),
          if (eventController.hasLocation)
            WidgetsEventCard.location(eventController: eventController),
          if ((eventController.masterUrl?.isNotEmpty ?? false) ||
              eventController.fee.isNotEmpty ||
              eventController.type.isNotEmpty ||
              eventController.description.isNotEmpty)
            WidgetsEventCard.metaRow(
              loc: loc,
              masterUrl: eventController.masterUrl,
              fee: eventController.fee,
              type: eventController.type,
              desc: eventController.description,
            ),
          if (showSubEvents)
            ...eventController.subEvents.map(
              (sub) => WidgetsEventSubCard(
                eventController: ControllerEvent(tableName: tableName, toTableName: constEmpty).eventController(sub),
                parentLocation: eventController.location,
              ),
            ),
        ],
      ),
    );

    final container = tableName != constTableCalendarEvents
        ? Card(
            margin: kGapEIH8V16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          )
        : Container(
            margin: kGapEIH8V16,
            child: content,
          );

    return GestureDetector(
      onTap: eventController.subEvents.isNotEmpty ? onTap : null,
      child: Stack(
        children: [
          container,
          if ((auth.currentAccount == constSysAdminEmail ||
                  auth.currentAccount == eventController.account) &&
              onDelete != null)
            PositionedDirectional(
              end: kGapW24().width,
              bottom: kGapH8().height,
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

  static Widget header({required String title, Widget? trailing}) {
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

  static Widget location({required EventController eventController}) {
    if (eventController.city.isEmpty && eventController.location.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text('${eventController.city}．${eventController.location}');
  }

  static Widget description(String desc) {
    if (desc.isEmpty) return const SizedBox.shrink();
    return Text(desc);
  }

  static Widget link({
    required AppLocalizations loc,
    required String url,
  }) {
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

  static Widget metaRow({
    required AppLocalizations loc,
    String? masterUrl,
    required String fee,
    required String type,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (masterUrl?.isNotEmpty == true) link(loc: loc, url: masterUrl!),
        if (desc.isNotEmpty) description(desc),
      ],
    );
  }

  static Widget tags({required String types}) {
    final typeList = types
        .split(RegExp(r'[\s,，]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList(); // \s 表示任何空白字元（空格、Tab、換行）
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: typeList.map((type) {
        return Container(
          padding: kGapEIH8V4,
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border.all(color: Colors.blue),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            type,
            style: const TextStyle(color: Colors.blue),
          ),
        );
      }).toList(),
    );
  }
}
