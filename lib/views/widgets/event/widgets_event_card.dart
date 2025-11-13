// lib/views/widgets/event/event_card_widgets.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_sub_card.dart';
import 'package:url_launcher/url_launcher.dart';

class WidgetsEventCard extends StatelessWidget {
  final EventViewModel eventViewModel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;
  final String tableName;
  final bool showSubEvents;

  const WidgetsEventCard({
    super.key,
    required this.eventViewModel,
    required this.tableName,
    this.onTap,
    this.onDelete,
    this.trailing,
    this.showSubEvents = true,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    Widget buildHeader() {
      return Row(
        children: [
          Expanded(
              child: Text(
            eventViewModel.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis, // 防止文字過長
            softWrap: true,
          )),
          if (trailing != null)
            Builder(
              builder: (context) {
                // 這裡的 context 已經在 widget 樹內，可以安全使用 Provider
                return trailing!;
              },
            ),
        ],
      );
    }

    final content = Padding(
      padding: Insets.all4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildHeader(),
          if (eventViewModel.dateRange.isNotEmpty)
            Text(eventViewModel.dateRange),
          if (eventViewModel.tags.isNotEmpty)
            tags(typeList: eventViewModel.tags),
          if (eventViewModel.hasLocation) Text(eventViewModel.locationDisplay),
          if (eventViewModel.masterUrl?.isNotEmpty == true)
            link(loc: loc, url: eventViewModel.masterUrl!),
          if (eventViewModel.description.isNotEmpty)
            Text(eventViewModel.description),
          if (showSubEvents)
            ...eventViewModel.subEvents
                .map((sub) => WidgetsEventSubCard(event: sub)),
        ],
      ),
    );

    final container = tableName != TableNames.calendarEvents
        ? Card(
            margin: Insets.h8v16,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.grey.shade100,
            elevation: 4,
            child: content,
          )
        : Container(
            margin: Insets.h8v16,
            child: content,
          );

    return GestureDetector(
      onTap: eventViewModel.subEvents.isNotEmpty ? onTap : null,
      child: Stack(
        children: [
          container,
          if (eventViewModel.canDelete && onDelete != null)
            PositionedDirectional(
              end: Gaps.w24.width,
              bottom: Gaps.h8.height,
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

  static Widget link({
    required AppLocalizations loc,
    required String url,
  }) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppNavigator.showSnackBar('${loc.url}: ${url.substring(0,url.length > 10 ? 10 : url.length)}');
      },
      child: Text(
        loc.clickHereToSeeMore,
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  static Widget tags({required List<String>? typeList}) {
    if (typeList == null) {
      return SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: typeList.map((type) {
        return Container(
          padding: Insets.h8v4,
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
