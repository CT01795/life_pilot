import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:life_pilot/utils/utils_widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCard extends StatelessWidget {
  final RecommendedEvent event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCard({
    super.key,
    required this.event,
    required this.index,
    required this.onTap,
    this.onDelete,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Colors.grey.shade100;
    //index % 2 == 0 ? Colors.grey.shade100 : Colors.grey.shade300;
    final auth = Provider.of<ControllerAuth>(context);
    final loc = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Card(
            margin: kGapEIH8V16,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            color: cardColor,
            elevation: 4,
            child: Padding(
              padding: kGapEI4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                  Text(
                    '${formatEventDateTime(event, "S")} - ${formatEventDateTime(event, "E")}',
                  ),
                  if (event.fee.isNotEmpty || event.type.isNotEmpty)
                    Text(
                      '${event.fee == '' ? '' : '${event.fee}．'}${event.type}',
                    ),
                  if (event.city.isNotEmpty || event.location.isNotEmpty)
                    Text(
                      '${event.city}．${event.location}',
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event.masterUrl != null &&
                          event.masterUrl!.isNotEmpty)
                        InkWell(
                          onTap: () async {
                            final Uri url = Uri.parse(event.masterUrl!);
                            await launchUrl(url,
                                mode: LaunchMode.externalApplication);
                            showSnackBar(context, '${loc.url}: $url');
                          },
                          child: Text(
                            event.masterUrl == null || event.masterUrl!.isEmpty
                                ? ''
                                : loc.click_here_to_see_more,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      kGapW8,
                      if (event.fee.isNotEmpty)
                        Padding(
                          padding: kGapEIT4,
                          child: widgetBuildTypeTags(event.fee),
                        ),
                      kGapW8,
                      if (event.type.isNotEmpty)
                        Padding(
                          padding: kGapEIT4,
                          child: widgetBuildTypeTags(event.type),
                        ),
                    ],
                  ),
                  ...event.subRecommendedEvents.asMap().entries.map(
                    (entry) {
                      final sub = entry.value;
                      //subIndex % 2 == 0 ? Colors.deepPurple.shade100 : Colors.deepPurple.shade50;

                      return SizedBox(
                        width : double.infinity,
                        child: Card(
                          color: Colors.transparent, 
                          elevation: 0, // 無陰影
                          margin: kGapEIL20R0T6B0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          child: Padding(
                            padding: kGapEI4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "👉 ${sub.name}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                    '${formatEventDateTime(sub, "S")} - ${formatEventDateTime(sub, "E")}',
                                ),
                                if (sub.fee.isNotEmpty || sub.type.isNotEmpty)
                                  Text(
                                    '${sub.fee == '' ? '' : '${sub.fee}．'}${sub.type}',
                                  ),
                                if ((sub.city.isNotEmpty ||
                                        sub.location.isNotEmpty) &&
                                    event.location != sub.location)
                                  Text(
                                    '${sub.city}．${sub.location}',
                                  ),
                                if (sub.subUrl != null &&
                                    sub.subUrl!.isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      final Uri url = Uri.parse(sub.subUrl!);
                                      await launchUrl(url,
                                          mode: LaunchMode.externalApplication);
                                      showSnackBar(context, '${loc.url}: $url');
                                    },
                                    child: Text(
                                      sub.subUrl == null || sub.subUrl!.isEmpty
                                          ? ''
                                          : loc.click_here_to_see_more,
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (auth.currentAccount == event.account && onDelete != null)
            Positioned(
              right : kGapW8.width,    
              bottom : kGapH8.height, 
              child: IconButton(
                icon: const Icon(Icons.delete, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: loc.delete,
              ),
            ),
        ],
      ),
    );
  }
}
