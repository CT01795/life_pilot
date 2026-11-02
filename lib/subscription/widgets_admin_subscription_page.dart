import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/subscription/controller_admin_subscription_page.dart';
import 'package:life_pilot/subscription/repository_admin_subscription_page.dart';
import 'package:life_pilot/subscription/model_admin_subscription_page.dart';
import 'package:life_pilot/utils/supabase.dart';

class AdminSubscriptionSummaryList extends StatefulWidget {
  const AdminSubscriptionSummaryList({
    super.key,
    required this.onSelected,
    this.load,
  });
  final ValueChanged<String> onSelected;
  final AdminSubscriptionPageLoader? load;
  @override
  State<AdminSubscriptionSummaryList> createState() =>
      _AdminSubscriptionSummaryListState();
}

class _AdminSubscriptionSummaryListState
    extends State<AdminSubscriptionSummaryList> {
  late final ControllerAdminSubscriptionPage _controller;
  @override
  void initState() {
    super.initState();
    _controller = ControllerAdminSubscriptionPage(
      auth: context.read<ControllerAuth>(),
      load: widget.load ?? RepositoryAdminSubscriptionPage(supabase).read,
    );
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final c = _controller;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: c.rows.length + 1,
            itemBuilder: (context, index) {
              if (index < c.rows.length) {
                final row = c.rows[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Tooltip(
                    message: row.email,
                    child: Text(
                      row.email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  subtitle: Text(
                    loc.adminSubscriptionActiveCount(row.activeEntitlements),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onSelected(row.email),
                );
              }
              if (c.loading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (c.error != null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(loc.dashboardLoadFailed),
                    TextButton.icon(
                      onPressed: () => c.load(more: c.retryMore),
                      icon: const Icon(Icons.refresh),
                      label: Text(loc.retry),
                    ),
                  ],
                );
              }
              if (c.hasMore) {
                return TextButton(
                  onPressed: () => c.load(more: true),
                  child: Text(loc.clickHereToSeeMore),
                );
              }
              if (c.rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(loc.noData),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}
