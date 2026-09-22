import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/service/service_personal_data.dart';

class AdminAccountDeletionRequests extends StatefulWidget {
  const AdminAccountDeletionRequests({super.key});

  @override
  State<AdminAccountDeletionRequests> createState() =>
      _AdminAccountDeletionRequestsState();
}

class _AdminAccountDeletionRequestsState
    extends State<AdminAccountDeletionRequests> {
  late Future<List<Map<String, dynamic>>> _requests;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _requests = ServicePersonalData().fetchAccountDeletionRequests();
  }

  Future<void> _approve(String id) async {
    setState(() => _busy = true);
    try {
      await ServicePersonalData().approveAccountDeletion(id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.adminAccountDeletionCompleted,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmCancellation(String id) async {
    setState(() => _busy = true);
    try {
      await ServicePersonalData().confirmAccountDeletionCancellation(id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.adminAccountDeletionCancellationConfirmed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.person_remove_outlined),
        title: Text(loc.accountMenuAccountDeletion),
        subtitle: Text(loc.adminSubscriptionTitle),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _requests,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                );
              }
              final requests = snapshot.data ?? const [];
              if (requests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(loc.accountListEmpty),
                );
              }
              return Column(
                children: requests.map((request) {
                  final id = request['id']?.toString() ?? '';
                  final email = request['email']?.toString() ?? '';
                  final status = request['status']?.toString() ?? 'pending';
                  final isCancellation = status == 'cancel_pending';
                  return ListTile(
                    title: Text(email),
                    subtitle: Text(
                      isCancellation
                          ? loc.adminAccountDeletionCancellationRequested
                          : request['requested_at']?.toString() ?? '',
                    ),
                    trailing: FilledButton(
                      onPressed: _busy || id.isEmpty
                          ? null
                          : () => isCancellation
                                ? _confirmCancellation(id)
                                : _approve(id),
                      child: Text(
                        isCancellation
                            ? loc.adminAccountDeletionConfirmCancellation
                            : loc.continueLabel,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
