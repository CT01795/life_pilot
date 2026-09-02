import 'package:flutter/material.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_card.dart';

class WidgetsEventDialog extends StatelessWidget {
  final ControllerEvent controllerEvent;
  final EventViewModel eventViewModel;
  final String tableName;
  const WidgetsEventDialog({
    super.key,
    required this.controllerEvent,
    required this.eventViewModel,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: Insets.h6,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: WidgetsEventCard(
                controllerEvent: controllerEvent,
                eventViewModel: eventViewModel,
                tableName: tableName,
                onTap: () => Navigator.pop(context),
                onOpenLink: () => controllerEvent.onOpenLink(eventViewModel),
                onOpenMap: () => controllerEvent.onOpenMap(eventViewModel),
              ),
            ),
            PositionedDirectional(
              end: Gaps.w8.width,
              top: Gaps.h8.height,
              child: _buildCloseButton(context: context, loc: loc),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloseButton(
      {required BuildContext context, required AppLocalizations loc}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 4,
            offset: const Offset(0, 2),
            color: colorScheme.shadow.withValues(alpha: 0.2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(Icons.close, color: colorScheme.onSurface),
        tooltip: loc.close,
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
