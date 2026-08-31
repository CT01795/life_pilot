import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

class CalendarSharingDialog extends StatefulWidget {
  const CalendarSharingDialog({
    required this.service,
    required this.visibleEvents,
    required this.onSharingChanged,
    super.key,
  });

  final ServiceCalendarSharing service;
  final List<EventItem> visibleEvents;
  final Future<void> Function() onSharingChanged;

  @override
  State<CalendarSharingDialog> createState() => _CalendarSharingDialogState();
}

class _CalendarSharingDialogState extends State<CalendarSharingDialog> {
  final _emailsController = TextEditingController();
  late Future<CalendarSharingState> _state;
  bool _submitting = false;
  final Set<String> _selectedEventIds = {};

  @override
  void initState() {
    super.initState();
    _state = _loadState();
  }

  @override
  void dispose() {
    _emailsController.dispose();
    super.dispose();
  }

  Future<CalendarSharingState> _loadState() async {
    final state = await widget.service.load(
      visibleEvents: widget.visibleEvents,
    );
    if (mounted &&
        _emailsController.text.trim().isEmpty &&
        state.sent.isNotEmpty) {
      _emailsController.text = state.sent.first.invitedEmail;
    }
    return state;
  }

  void _reload() => setState(() => _state = _loadState());

  Future<void> _run(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      await widget.onSharingChanged();
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.calendarInvitationFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _invite() async {
    final emails = _emailsController.text
        .split(RegExp(r'[,;\s]+'))
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.isNotEmpty)
        .toSet();
    if (emails.isEmpty || _selectedEventIds.isEmpty) return;
    await _run(() => widget.service.inviteAll(emails, _selectedEventIds));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.calendarSharing),
      content: SizedBox(
        width: 560,
        child: FutureBuilder<CalendarSharingState>(
          future: _state,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final state = snapshot.data!;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(loc.calendarInvite,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailsController,
                    enabled: !_submitting,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: loc.calendarInviteHint,
                      suffixIcon: IconButton(
                        tooltip: loc.calendarInvite,
                        onPressed: _submitting ? null : _invite,
                        icon: const Icon(Icons.send),
                      ),
                    ),
                    onSubmitted: (_) => _invite(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.calendarShareEvents,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (state.shareableEvents.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(loc.calendarNoShareableEvents),
                    )
                  else ...[
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: state.shareableEvents.every(
                        (event) => _selectedEventIds.contains(event.id),
                      ),
                      title: Text(loc.calendarShareAllEvents),
                      onChanged: _submitting
                          ? null
                          : (selected) => setState(() {
                                if (selected == true) {
                                  _selectedEventIds.addAll(
                                    state.shareableEvents
                                        .map((event) => event.id),
                                  );
                                } else {
                                  _selectedEventIds.clear();
                                }
                              }),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.shareableEvents.length,
                        itemBuilder: (context, index) {
                          final event = state.shareableEvents[index];
                          final date = event.startDate == null
                              ? ''
                              : MaterialLocalizations.of(context)
                                  .formatShortDate(event.startDate!.toLocal());
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: _selectedEventIds.contains(event.id),
                            title: Text(event.name),
                            subtitle: date.isEmpty ? null : Text(date),
                            onChanged: _submitting
                                ? null
                                : (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedEventIds.add(event.id);
                                      } else {
                                        _selectedEventIds.remove(event.id);
                                      }
                                    }),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle(context, loc.calendarSentInvitations),
                  ...state.sent.map((item) {
                    final sharedEvents = state.eventsForInvitation(item.id);
                    return ExpansionTile(
                      leading: const Icon(Icons.upload_outlined),
                      title: Text(item.invitedEmail),
                      subtitle: Text(_statusLabel(loc, item.status)),
                      children: [
                        if (sharedEvents.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(loc.calendarNoSharedEvents),
                          ),
                        ...sharedEvents.map((event) {
                          final date = event.startDate == null
                              ? ''
                              : MaterialLocalizations.of(context)
                                  .formatShortDate(event.startDate!.toLocal());
                          return ListTile(
                            dense: true,
                            title: Text(event.name),
                            subtitle: date.isEmpty ? null : Text(date),
                            trailing: IconButton(
                              tooltip: loc.calendarCancelSingleShare,
                              onPressed: _submitting
                                  ? null
                                  : () => _run(
                                        () => widget.service.removeSharedEvent(
                                          invitationId: item.id,
                                          eventId: event.eventId,
                                        ),
                                      ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          );
                        }),
                        if (item.isPending || item.isAccepted)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _run(
                                        () => widget.service.revoke(item.id),
                                      ),
                              icon: const Icon(Icons.link_off),
                              label: Text(loc.calendarCancelAllShares),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  _sectionTitle(context, loc.calendarReceivedInvitations),
                  ...state.received.map((item) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.download_outlined),
                        title: Text(item.sharedBy),
                        subtitle: Text(_statusLabel(loc, item.status)),
                        trailing: item.isPending
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () =>
                                            _run(() => widget.service.respond(
                                                  invitationId: item.id,
                                                  accept: false,
                                                )),
                                    child: Text(loc.calendarInvitationDecline),
                                  ),
                                  FilledButton(
                                    onPressed: _submitting
                                        ? null
                                        : () =>
                                            _run(() => widget.service.respond(
                                                  invitationId: item.id,
                                                  accept: true,
                                                )),
                                    child: Text(loc.calendarInvitationAccept),
                                  ),
                                ],
                              )
                            : item.isAccepted
                                ? TextButton(
                                    onPressed: _submitting
                                        ? null
                                        : () => _run(
                                              () => widget.service.respond(
                                                invitationId: item.id,
                                                accept: false,
                                              ),
                                            ),
                                    child: Text(loc.calendarStopReceiving),
                                  )
                                : null,
                      )),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(loc.close),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );

  String _statusLabel(AppLocalizations loc, String status) => switch (status) {
        'accepted' => loc.calendarInvitationAccepted,
        'declined' => loc.calendarInvitationDeclined,
        'revoked' => loc.calendarInvitationRevoked,
        _ => loc.calendarInvitationPending,
      };
}
