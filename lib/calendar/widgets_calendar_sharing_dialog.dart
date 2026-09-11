import 'package:flutter/material.dart';
import 'package:life_pilot/calendar/service_calendar_sharing.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

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
  final _dialogScrollController = ScrollController();
  final _shareableEventsScrollController = ScrollController();
  final _sentInvitationsScrollController = ScrollController();
  final _receivedInvitationsScrollController = ScrollController();
  late Future<CalendarSharingState> _state;
  bool _submitting = false;
  String? _emailError;
  bool _eventSelectionError = false;
  final Set<String> _selectedEventIds = {};
  final Set<String> _expandedSentInvitationIds = {};

  @override
  void initState() {
    super.initState();
    _state = _loadState();
  }

  @override
  void dispose() {
    _emailsController.dispose();
    _dialogScrollController.dispose();
    _shareableEventsScrollController.dispose();
    _sentInvitationsScrollController.dispose();
    _receivedInvitationsScrollController.dispose();
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

  Future<void> _run(
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      await context.read<ControllerAuth>().refreshSubscriptionUsage();
      await widget.onSharingChanged();
      if (mounted) {
        _reload();
        if (successMessage != null) {
          final messenger = ScaffoldMessenger.of(context);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(successMessage)));
        }
      }
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
    final loc = AppLocalizations.of(context)!;
    final emails = _splitEmails(_emailsController.text);
    final invalidEmail = emails.any(
      (email) => !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email),
    );
    if (emails.isEmpty || invalidEmail || _selectedEventIds.isEmpty) {
      setState(() {
        _emailError = emails.isEmpty
            ? loc.noEmailError
            : invalidEmail
                ? loc.invalidEmail
                : null;
        _eventSelectionError = _selectedEventIds.isEmpty;
      });
      return;
    }
    setState(() {
      _emailError = null;
      _eventSelectionError = false;
    });
    await _run(
      () => widget.service.inviteAll(emails, _selectedEventIds),
      successMessage: loc.calendarInvitationSent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.calendarSharing),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width.clamp(0, 560).toDouble(),
        child: FutureBuilder<CalendarSharingState>(
          future: _state,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return SizedBox(
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40),
                      Gaps.h8,
                      Text(loc.calendarInvitationFailed),
                      Gaps.h8,
                      OutlinedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: Text(loc.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            final state = snapshot.data!;
            final auth = context.watch<ControllerAuth>();
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Scrollbar(
                controller: _dialogScrollController,
                thumbVisibility: true,
                thickness: 4,
                radius: const Radius.circular(8),
                child: ListView(
                controller: _dialogScrollController,
                shrinkWrap: true,
                padding: const EdgeInsetsDirectional.only(end: 10),
                children: [
                  if (auth.preferredStorage == DataStorageLocation.cloud)
                    const SubscriptionUsageBanner(
                      resource: 'calendar_shares',
                    ),
                  if (_submitting) ...[
                    const LinearProgressIndicator(),
                    Gaps.h16,
                  ],
                  _sectionTitle(context, loc.calendarInvite),
                  Gaps.h8,
                  TextField(
                    controller: _emailsController,
                    enabled: !_submitting,
                    minLines: 1,
                    maxLines: 3,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: loc.calendarInviteHint,
                      errorText: _emailError,
                      suffixIcon: IconButton(
                        tooltip: loc.calendarInvite,
                        onPressed: _submitting ? null : _invite,
                        icon: const Icon(Icons.send),
                      ),
                    ),
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    onSubmitted: (_) => _invite(),
                  ),
                  _emailChips(context),
                  Gaps.h16,
                  _sectionTitle(
                    context,
                    loc.calendarShareEvents,
                    count: state.shareableEvents.length,
                  ),
                  if (state.shareableEvents.isEmpty)
                    _emptySection(context, loc.calendarNoShareableEvents)
                  else ...[
                    CheckboxListTile(
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 4,
                        end: 12,
                      ),
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
                                _eventSelectionError = false;
                              }),
                    ),
                    _scrollableListPanel(
                      context: context,
                      controller: _shareableEventsScrollController,
                      height: (state.shareableEvents.length * 72.0)
                          .clamp(72.0, 220.0),
                      showHint: state.shareableEvents.length > 3,
                      child: ListView.builder(
                        controller: _shareableEventsScrollController,
                        primary: false,
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        itemExtent: 72,
                        cacheExtent: 144,
                        addAutomaticKeepAlives: false,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: state.shareableEvents.length,
                        itemBuilder: (context, index) {
                          final event = state.shareableEvents[index];
                          final date = event.startDate == null
                              ? ''
                              : MaterialLocalizations.of(context)
                                  .formatShortDate(event.startDate!.toLocal());
                          return CheckboxListTile(
                            contentPadding: const EdgeInsetsDirectional.only(
                              start: 8,
                              end: 16,
                            ),
                            value: _selectedEventIds.contains(event.id),
                            title: Text(
                              event.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w500),
                            ),
                            subtitle: date.isEmpty
                                ? null
                                : Text(
                                    date,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                            onChanged: _submitting
                                ? null
                                : (selected) => setState(() {
                                      if (selected == true) {
                                        _selectedEventIds.add(event.id);
                                      } else {
                                        _selectedEventIds.remove(event.id);
                                      }
                                      _eventSelectionError = false;
                                    }),
                          );
                        },
                      ),
                    ),
                  ],
                  if (_eventSelectionError)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 12,
                        top: 6,
                      ),
                      child: Text(
                        loc.calendarSelectEventRequired,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  Gaps.h16,
                  _sectionTitle(
                    context,
                    loc.calendarSentInvitations,
                    count: state.sent.length,
                  ),
                  if (state.sent.isEmpty)
                    _emptySection(context, loc.noData)
                  else
                    _scrollableListPanel(
                      context: context,
                      controller: _sentInvitationsScrollController,
                      height: (state.sent.length * 72.0)
                          .clamp(72.0, 300.0)
                          .toDouble(),
                      showHint: state.sent.length > 4,
                      child: ListView.builder(
                        controller: _sentInvitationsScrollController,
                        primary: false,
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        cacheExtent: 144,
                        addAutomaticKeepAlives: false,
                        itemCount: state.sent.length,
                        itemBuilder: (context, index) => _sentInvitationTile(
                          context,
                          loc,
                          state,
                          state.sent[index],
                        ),
                      ),
                    ),
                  Gaps.h16,
                  _sectionTitle(
                    context,
                    loc.calendarReceivedInvitations,
                    count: state.received.length,
                  ),
                  if (state.received.isEmpty)
                    _emptySection(context, loc.noData)
                  else
                    _scrollableListPanel(
                      context: context,
                      controller: _receivedInvitationsScrollController,
                      height: (state.received.length * 88.0)
                          .clamp(72.0, 280.0)
                          .toDouble(),
                      showHint: state.received.length > 3,
                      child: ListView.builder(
                        controller: _receivedInvitationsScrollController,
                        primary: false,
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        cacheExtent: 144,
                        addAutomaticKeepAlives: false,
                          itemCount: state.received.length,
                          itemBuilder: (context, index) =>
                              _receivedInvitationTile(
                            context,
                            loc,
                            state.received[index],
                          ),
                      ),
                    ),
                ],
                ),
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

  Widget _sentInvitationTile(
    BuildContext context,
    AppLocalizations loc,
    CalendarSharingState state,
    CalendarShareInvitation item,
  ) {
    final isExpanded = _expandedSentInvitationIds.contains(item.id);
    final sharedEvents = isExpanded
        ? state.eventsForInvitation(item.id)
        : const <SharedCalendarEvent>[];
    return ExpansionTile(
      key: PageStorageKey('calendar-share-${item.id}'),
      tilePadding: const EdgeInsetsDirectional.only(start: 12, end: 8),
      childrenPadding: const EdgeInsetsDirectional.only(start: 8, end: 8),
      leading: _directionIcon(context, Icons.upload_outlined),
      title: Text(item.invitedEmail, overflow: TextOverflow.ellipsis),
      subtitle: Align(
        alignment: AlignmentDirectional.centerStart,
        child: _statusChip(context, loc, item.status),
      ),
      onExpansionChanged: (expanded) => setState(() {
        if (expanded) {
          _expandedSentInvitationIds.add(item.id);
        } else {
          _expandedSentInvitationIds.remove(item.id);
        }
      }),
      children: isExpanded
          ? [
              if (sharedEvents.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(loc.calendarNoSharedEvents),
                ),
              if (sharedEvents.isNotEmpty)
                SizedBox(
                  height: (sharedEvents.length * 64.0)
                      .clamp(64.0, 256.0)
                      .toDouble(),
                  child: ListView.builder(
                    key: PageStorageKey('calendar-share-events-${item.id}'),
                    primary: false,
                    itemExtent: 64,
                    cacheExtent: 64,
                    addAutomaticKeepAlives: false,
                    itemCount: sharedEvents.length,
                    itemBuilder: (context, index) {
                      final event = sharedEvents[index];
                      final date = event.startDate == null
                          ? ''
                          : MaterialLocalizations.of(context)
                              .formatShortDate(event.startDate!.toLocal());
                      return ListTile(
                        dense: true,
                        title: Text(
                          event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: date.isEmpty ? null : Text(date),
                        trailing: IconButton(
                          tooltip: loc.calendarCancelSingleShare,
                          onPressed: _submitting
                              ? null
                              : () => _confirmAndRun(
                                    context: context,
                                    title: loc.calendarCancelSingleShare,
                                    subject: event.name,
                                    action: () =>
                                        widget.service.removeSharedEvent(
                                      invitationId: item.id,
                                      eventId: event.eventId,
                                    ),
                                  ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      );
                    },
                  ),
                ),
              if (item.isPending || item.isAccepted)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _confirmAndRun(
                              context: context,
                              title: loc.calendarCancelAllShares,
                              subject: item.invitedEmail,
                              action: () => widget.service.revoke(item.id),
                            ),
                    icon: const Icon(Icons.link_off),
                    label: Text(loc.calendarCancelAllShares),
                  ),
                ),
            ]
          : const [],
    );
  }

  Widget _receivedInvitationTile(
    BuildContext context,
    AppLocalizations loc,
    CalendarShareInvitation item,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsetsDirectional.only(start: 12, end: 8),
            leading: _directionIcon(context, Icons.download_outlined),
            title: Text(item.sharedBy, overflow: TextOverflow.ellipsis),
            subtitle: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _statusChip(context, loc, item.status),
            ),
          ),
          if (item.isPending || item.isAccepted)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 8,
                bottom: 8,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: [
                    if (item.isPending) ...[
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => _confirmAndRun(
                                  context: context,
                                  title: loc.calendarInvitationDecline,
                                  subject: item.sharedBy,
                                  action: () => widget.service.respond(
                                    invitationId: item.id,
                                    accept: false,
                                  ),
                                ),
                        child: Text(loc.calendarInvitationDecline),
                      ),
                      FilledButton(
                        onPressed: _submitting
                            ? null
                            : () => _run(
                                  () => widget.service.respond(
                                    invitationId: item.id,
                                    accept: true,
                                  ),
                                  successMessage: loc.calendarSharingUpdated,
                                ),
                        child: Text(loc.calendarInvitationAccept),
                      ),
                    ] else
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => _confirmAndRun(
                                  context: context,
                                  title: loc.calendarStopReceiving,
                                  subject: item.sharedBy,
                                  action: () => widget.service.respond(
                                    invitationId: item.id,
                                    accept: false,
                                  ),
                                ),
                        child: Text(loc.calendarStopReceiving),
                      ),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
        ],
      );

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String subject,
    required Future<void> Function() action,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(subject),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(loc.confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(action, successMessage: loc.calendarSharingUpdated);
    }
  }

  Set<String> _splitEmails(String value) => value
      .split(RegExp(r'[,;\s]+'))
      .map((email) => email.trim().toLowerCase())
      .where((email) => email.isNotEmpty)
      .toSet();

  Widget _emailChips(BuildContext context) => ValueListenableBuilder(
        valueListenable: _emailsController,
        builder: (context, value, _) {
          final emails = _splitEmails(value.text);
          if (emails.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: emails
                  .map(
                    (email) => ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: InputChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onDeleted: _submitting
                            ? null
                            : () {
                                emails.remove(email);
                                final text = emails.join(', ');
                                _emailsController.value = TextEditingValue(
                                  text: text,
                                  selection: TextSelection.collapsed(
                                    offset: text.length,
                                  ),
                                );
                              },
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      );

  Widget _directionIcon(BuildContext context, IconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: .65),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: colors.onPrimaryContainer),
    );
  }

  Widget _statusChip(
    BuildContext context,
    AppLocalizations loc,
    String status,
  ) {
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      'accepted' => (
          colors.primaryContainer.withValues(alpha: .7),
          colors.onPrimaryContainer,
        ),
      'declined' => (
          colors.errorContainer.withValues(alpha: .65),
          colors.onErrorContainer,
        ),
      'revoked' => (
          colors.surfaceContainerHighest,
          colors.onSurfaceVariant,
        ),
      _ => (
          colors.tertiaryContainer.withValues(alpha: .7),
          colors.onTertiaryContainer,
        ),
    };
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(loc, status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String text, {
    int? count,
  }) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            if (count != null)
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
      );

  Widget _emptySection(BuildContext context, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerLowest
              .withValues(alpha: .5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Widget _scrollableListPanel({
    required BuildContext context,
    required ScrollController controller,
    required double height,
    required bool showHint,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHint)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: 1,
              end: 6,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.swipe_vertical_rounded,
                  size: 15,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  loc.scrollThisArea,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: .65),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: WidgetStatePropertyAll(
                    colors.primary.withValues(alpha: .65),
                  ),
                  trackColor: WidgetStatePropertyAll(
                    colors.primary.withValues(alpha: .06),
                  ),
                  trackBorderColor:
                      const WidgetStatePropertyAll(Colors.transparent),
                  thickness: const WidgetStatePropertyAll(5),
                  radius: const Radius.circular(8),
                ),
                child: Scrollbar(
                  controller: controller,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: ListTileTheme.merge(
                    minVerticalPadding: 8,
                    titleTextStyle:
                        Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                    subtitleTextStyle: Theme.of(context).textTheme.bodySmall,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _statusLabel(AppLocalizations loc, String status) => switch (status) {
        'accepted' => loc.calendarInvitationAccepted,
        'declined' => loc.calendarInvitationDeclined,
        'revoked' => loc.calendarInvitationRevoked,
        _ => loc.calendarInvitationPending,
      };
}
