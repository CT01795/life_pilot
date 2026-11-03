import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LedgerKind { accounting, points }

class ServiceLedgerSharing {
  ServiceLedgerSharing({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? supabase;
  static const _group = 'ledger-sharing';
  static const pageSize = 30;

  Future<List<Map<String, dynamic>>> homeLinks() =>
      RepositorySessionReads(_db).read(_group, 'home-links', () async {
        final rows = await _db.rpc('list_my_ledger_home_links');
        return List<Map<String, dynamic>>.from(rows as List);
      });

  Future<void> setHomeLink(String id, bool linked) async {
    await _write('set_my_ledger_home_link', {
      'p_share_id': id,
      'p_linked': linked,
    });
  }

  Future<List<Map<String, dynamic>>> received(int offset) =>
      _read('list_my_shared_ledgers', {}, offset);

  Future<List<Map<String, dynamic>>> receivedKindPage(
    LedgerKind kind,
    int offset, {
    int limit = pageSize,
  }) async {
    try {
      return await _read(
        'list_my_shared_ledgers_by_kind',
        {'p_kind': kind.name},
        offset,
        limit: limit,
      );
    } on PostgrestException catch (error) {
      if (error.code != 'PGRST202') rethrow;
      return (await receivedFor(
        kind,
        maxResults: offset + limit,
      )).skip(offset).take(limit).toList(growable: false);
    }
  }

  Future<List<Map<String, dynamic>>> receivedFor(
    LedgerKind kind, {
    int? maxResults,
  }) => RepositorySessionReads(_db).read(_group, (
    'received',
    kind,
    maxResults,
  ), () => _receivedFor(kind, maxResults));

  Future<List<Map<String, dynamic>>> _receivedFor(
    LedgerKind kind,
    int? maxResults,
  ) async {
    final result = <Map<String, dynamic>>[];
    var legacy = false;
    var offset = 0;
    while (maxResults == null || result.length < maxResults) {
      final limit = legacy || maxResults == null
          ? pageSize
          : (maxResults - result.length).clamp(1, pageSize).toInt();
      final List<Map<String, dynamic>> page;
      try {
        page = legacy
            ? await received(offset)
            : await _read(
                'list_my_shared_ledgers_by_kind',
                {'p_kind': kind.name},
                offset,
                limit: limit,
              );
      } on PostgrestException catch (error) {
        if (legacy || offset != 0 || error.code != 'PGRST202') rethrow;
        legacy = true;
        continue;
      }
      result.addAll(page.where((row) => row['kind'] == kind.name));
      if (page.length < limit) break;
      offset += page.length;
    }
    return List.unmodifiable(
      maxResults == null ? result : result.take(maxResults),
    );
  }

  Future<List<Map<String, dynamic>>> entries(String id, int offset) =>
      _read('read_my_shared_ledger_entries', {'p_share_id': id}, offset);

  Future<List<Map<String, dynamic>>> outgoing(
    LedgerKind kind,
    String accountId,
    int offset,
  ) => _read('list_my_outgoing_ledger_shares', {
    'p_kind': kind.name,
    'p_account_id': accountId,
  }, offset);

  Future<void> share(LedgerKind kind, String accountId, String email) async {
    await _write('share_my_ledger_for_reading', {
      'p_kind': kind.name,
      'p_account_id': accountId,
      'p_recipient_email': email,
    });
  }

  Future<void> revoke(String id) async {
    await _write('revoke_my_ledger_read_share', {'p_share_id': id});
  }

  Future<List<Map<String, dynamic>>> proposals(String id, int offset) =>
      _read('list_my_ledger_change_proposals', {'p_share_id': id}, offset);

  Future<void> allowProposals(String id, bool allowed) async {
    await _write('set_my_ledger_share_change_permission', {
      'p_share_id': id,
      'p_allowed': allowed,
    });
  }

  Future<void> review(String id, bool approve) async {
    await _write('review_my_ledger_change', {
      'p_proposal_id': id,
      'p_approve': approve,
    });
  }

  Future<bool> canPropose(String id) async =>
      await _db.rpc(
        'can_propose_shared_ledger_change',
        params: {'p_share_id': id},
      ) ==
      true;

  Future<void> submitProposal(
    String shareId,
    String operation,
    String? entryId,
    Map<String, Object?> changes,
  ) async {
    await _write('submit_shared_ledger_change', {
      'p_share_id': shareId,
      'p_operation': operation,
      'p_entry_id': entryId,
      'p_changes': changes,
    });
  }

  Future<void> _write(String rpc, Map<String, Object?> params) async {
    final client = _db;
    final reads = RepositorySessionReads(client);
    reads.invalidate(_group);
    try {
      await client.rpc(rpc, params: params);
    } finally {
      reads.invalidate(_group);
    }
  }

  Future<List<Map<String, dynamic>>> _read(
    String rpc,
    Map<String, Object?> params,
    int offset, {
    int limit = pageSize,
  }) => RepositorySessionReads(_db).read(
    _group,
    (
      rpc,
      params['p_kind'],
      params['p_account_id'],
      params['p_share_id'],
      offset,
      limit,
    ),
    () async {
      final rows = await _db.rpc(
        rpc,
        params: {...params, 'p_limit': limit, 'p_offset': offset},
      );
      return List<Map<String, dynamic>>.unmodifiable(
        (rows as List).map(
          (row) => Map<String, dynamic>.unmodifiable(row as Map),
        ),
      );
    },
  );
}
