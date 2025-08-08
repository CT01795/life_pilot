import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/utils/utils_class_event_card.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:life_pilot/utils/utils_widgets.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCardGraph extends StatelessWidget {
  final RecommendedEvent event;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Widget? trailing;

  const EventCardGraph({
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
    final loc = AppLocalizations.of(context)!;
    final auth = Provider.of<ControllerAuth>(context);
    //index % 2 == 0 ? Colors.grey.shade100 : Colors.grey.shade300;
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
                ],
              ),
            ),
          ),
          if (auth.currentAccount == event.account && onDelete != null)
            Positioned(
              right: kGapW8.width,
              bottom: kGapH8.height,
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

class EventImageDialog extends StatelessWidget {
  final RecommendedEvent event;
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

          Positioned(
            right : kGapW8.width,
            top : kGapH8.height,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.close, ),
                tooltip: loc.close,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
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
          child: Image.network(
            imageUrl.replaceFirst('dl=0', 'raw=1'),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
