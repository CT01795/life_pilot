import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

class EventCompletionChoice {
  const EventCompletionChoice({required this.addToMemory});

  final bool addToMemory;
}

Future<EventCompletionChoice?> showEventCompletionSheet(
  BuildContext context, {
  required String eventName,
}) =>
    showModalBottomSheet<EventCompletionChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _EventCompletionSheet(eventName: eventName),
    );

class _EventCompletionSheet extends StatefulWidget {
  const _EventCompletionSheet({required this.eventName});

  final String eventName;

  @override
  State<_EventCompletionSheet> createState() => _EventCompletionSheetState();
}

class _EventCompletionSheetState extends State<_EventCompletionSheet> {
  bool _addToMemory = true;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Gaps.h16,
          Text(loc.completeEventTitle, style: textTheme.headlineSmall),
          Gaps.h8,
          Text(widget.eventName, style: textTheme.titleMedium),
          Gaps.h4,
          Text(loc.completeEventMessage),
          Gaps.h12,
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _addToMemory,
            title: Text(loc.memoryAdd),
            secondary: const Icon(Icons.auto_stories_outlined),
            controlAffinity: ListTileControlAffinity.trailing,
            onChanged: (value) {
              setState(() => _addToMemory = value ?? false);
            },
          ),
          Gaps.h16,
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(loc.cancel),
                ),
              ),
              Gaps.w12,
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(
                    context,
                    EventCompletionChoice(addToMemory: _addToMemory),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(loc.confirm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
