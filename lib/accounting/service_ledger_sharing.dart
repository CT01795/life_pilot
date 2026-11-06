import 'dart:async';

import 'package:life_pilot/record_statistics/model_record_statistics_buckets.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum LedgerKind { accounting, points }

typedef SharedLedgerHomeSnapshot = ({
  Map<String, dynamic> totals,
  List<Map<String, dynamic>> entries,
});

typedef SharedLedgerDetailReads = ({
  Future<bool> canPropose,
  Future<Map<String, dynamic>> totals,
  Future<List<Map<String, dynamic>>> entries,
});

class ServiceLedgerSharing {
  ServiceLedgerSharing({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? supabase;
  static const _group = 'ledger-sharing';
  static const _homeLinksGroup = 'ledger-sharing-home-links';
  static const _pendingGroup = 'ledger-sharing-pending';
  static const pageSize = 30;
  static const _totalsBatchSize = 12;
  static const _kindRpc = 'list_my_shared_ledgers_by_kind';
  static const _batchRpc = 'get_my_shared_ledger_totals_batch';
  static const _overviewWindowRpc = 'list_my_shared_ledger_overview_window';
  static final _totalsQueues =
      Expando<
        Map<(String, DateTime), Map<String, Completer<Map<String, dynamic>>>>
      >();

  Future<List<Map<String, dynamic>>> homeLinks() =>
      RepositorySessionReads(_db).read(_homeLinksGroup, 'home-links', () async {
        final rows = await _db.rpc('list_my_ledger_home_links');
        return List<Map<String, dynamic>>.from(rows as List);
      });

  Future<void> setHomeLink(String id, bool linked) async {
    final client = _db;
    final reads = RepositorySessionReads(client);
    reads.invalidate(_homeLinksGroup);
    try {
      await client.rpc(
        'set_my_ledger_home_link',
        params: {'p_share_id': id, 'p_linked': linked},
      );
    } finally {
      reads.invalidate(_homeLinksGroup);
    }
  }

  Future<List<Map<String, dynamic>>> overviewPage(
    LedgerKind kind,
    int offset, {
    required int limit,
    required int visibleLimit,
  }) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    String utc(DateTime date) => date.toUtc().toIso8601String();
    final params = {
      'p_kind': kind.name,
      'p_month_start': utc(DateTime(day.year, day.month)),
      'p_month_end': utc(DateTime(day.year, day.month + 1)),
      'p_day_start': utc(day),
      'p_day_end': utc(DateTime(day.year, day.month, day.day + 1)),
    };
    return _read(
      _overviewWindowRpc,
      {...params, 'p_visible_limit': visibleLimit},
      offset,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> receivedKindPage(
    LedgerKind kind,
    int offset, {
    int limit = pageSize,
  }) => _read(_kindRpc, {'p_kind': kind.name}, offset, limit: limit);

  Future<List<Map<String, dynamic>>> entries(String id, int offset) =>
      _read('read_my_shared_ledger_entries', {'p_share_id': id}, offset);

  Future<List<Map<String, dynamic>>> statistics(String id, DateTime now) =>
      RepositorySessionReads(_db).read(
        _group,
        ('statistics', id, now.year, now.month, now.day),
        () async {
          String utc(DateTime date) => date.toUtc().toIso8601String();
          final result = await _db.rpc(
            'get_my_shared_ledger_statistics',
            params: {
              'p_share_id': id,
              'p_boundaries': [
                for (var i = -11; i <= 1; i++)
                  utc(DateTime(now.year, now.month + i)),
              ],
              'p_day_start': utc(DateTime(now.year, now.month, now.day)),
              'p_day_end': utc(DateTime(now.year, now.month, now.day + 1)),
            },
          );
          return ModelRecordStatisticsBuckets.toRows(
            Map<String, dynamic>.from(result as Map),
            now,
          );
        },
      );

  Future<SharedLedgerHomeSnapshot> homePreview(String id) {
    const rpc = 'get_my_shared_ledger_home_preview';
    final db = _db;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    String utc(DateTime date) => date.toUtc().toIso8601String();
    return RepositorySessionReads(
      db,
    ).read(_group, ('home-preview', id, day), () async {
      final result =
          await db.rpc(
                rpc,
                params: {
                  'p_share_id': id,
                  'p_month_start': utc(DateTime(day.year, day.month)),
                  'p_month_end': utc(DateTime(day.year, day.month + 1)),
                  'p_day_start': utc(day),
                  'p_day_end': utc(DateTime(day.year, day.month, day.day + 1)),
                },
              )
              as Map;
      return (
        totals: Map<String, dynamic>.unmodifiable(result['totals'] as Map),
        entries: List<Map<String, dynamic>>.unmodifiable(
          (result['entries'] as List).map(
            (row) => Map<String, dynamic>.unmodifiable(row as Map),
          ),
        ),
      );
    });
  }

  SharedLedgerDetailReads detailFirstPage(String id) {
    const rpc = 'get_my_shared_ledger_detail_first_page';
    final db = _db;
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    String utc(DateTime date) => date.toUtc().toIso8601String();
    final snapshot = RepositorySessionReads(db).read<Map>(
      _group,
      ('detail-first', id, day),
      () async {
        return await db.rpc(
              rpc,
              params: {
                'p_share_id': id,
                'p_limit': pageSize,
                'p_month_start': utc(DateTime(day.year, day.month)),
                'p_month_end': utc(DateTime(day.year, day.month + 1)),
                'p_day_start': utc(day),
                'p_day_end': utc(DateTime(day.year, day.month, day.day + 1)),
              },
            )
            as Map;
      },
    );
    return (
      canPropose: snapshot.then((row) => row['can_propose'] == true),
      totals: snapshot.then(
        (row) => Map<String, dynamic>.unmodifiable(row['totals'] as Map),
      ),
      entries: snapshot.then(
        (row) => List<Map<String, dynamic>>.unmodifiable(
          (row['entries'] as List).map(
            (entry) => Map<String, dynamic>.unmodifiable(entry as Map),
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> totals(String id, {DateTime? now}) {
    final date = now ?? DateTime.now();
    final month = DateTime(date.year, date.month);
    final day = DateTime(date.year, date.month, date.day);
    return RepositorySessionReads(
      _db,
    ).read(_group, ('totals', id, month, day), () => _queueTotals(id, day));
  }

  Future<Map<String, dynamic>> _queueTotals(String id, DateTime day) {
    final db = _db;
    final token = db.auth.currentSession!.accessToken;
    final key = (token, day);
    final queues = _totalsQueues[db] ??= {};
    final pending = queues.putIfAbsent(key, () {
      scheduleMicrotask(() {
        final requests = queues.remove(key)!;
        if (db.auth.currentSession?.accessToken != token) {
          for (final request in requests.values) {
            request.completeError(StateError('Read scope changed'));
          }
          return;
        }
        final ids = requests.keys.toList(growable: false);
        for (var i = 0; i < ids.length; i += _totalsBatchSize) {
          final chunk = ids.skip(i).take(_totalsBatchSize);
          unawaited(
            _flushTotals(db, token, day, {
              for (final id in chunk) id: requests[id]!,
            }),
          );
        }
      });
      return {};
    });
    return pending.putIfAbsent(id, Completer<Map<String, dynamic>>.new).future;
  }

  static Future<void> _flushTotals(
    SupabaseClient db,
    String token,
    DateTime day,
    Map<String, Completer<Map<String, dynamic>>> requests,
  ) async {
    String utc(DateTime value) => value.toUtc().toIso8601String();
    final range = {
      'p_month_start': utc(DateTime(day.year, day.month)),
      'p_month_end': utc(DateTime(day.year, day.month + 1)),
      'p_day_start': utc(day),
      'p_day_end': utc(DateTime(day.year, day.month, day.day + 1)),
    };
    Future<void> readOne(
      String id,
      Completer<Map<String, dynamic>> request,
    ) async {
      try {
        if (db.auth.currentSession?.accessToken != token) {
          throw StateError('Read scope changed');
        }
        final row = await db.rpc(
          'get_my_shared_ledger_totals',
          params: {...range, 'p_share_id': id},
        );
        request.complete(Map<String, dynamic>.unmodifiable(row as Map));
      } catch (error, stack) {
        request.completeError(error, stack);
      }
    }

    if (requests.length == 1) {
      await readOne(requests.keys.single, requests.values.single);
      return;
    }
    try {
      final rows =
          await db.rpc(
                _batchRpc,
                params: {
                  ...range,
                  'p_share_ids': requests.keys.toList(growable: false),
                },
              )
              as Map;
      for (final entry in requests.entries) {
        final row = rows[entry.key];
        if (row is Map) {
          entry.value.complete(Map<String, dynamic>.unmodifiable(row));
        } else {
          entry.value.completeError(
            const PostgrestException(
              message: 'ledger_share_unavailable',
              code: '42501',
            ),
          );
        }
      }
    } catch (error, stack) {
      for (final request in requests.values.where(
        (request) => !request.isCompleted,
      )) {
        request.completeError(error, stack);
      }
    }
  }

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

  Future<void> decline(String id) =>
      _write('decline_my_ledger_share', {'p_share_id': id});

  Future<List<Map<String, dynamic>>> accountProposals(
    LedgerKind kind,
    String id,
    int offset,
  ) => _read('list_my_ledger_account_pending_proposals', {
    'p_kind': kind.name,
    'p_account_id': id,
  }, offset);

  Future<Map<String, int>> pendingCounts(
    LedgerKind kind, {
    String? accountId,
  }) => RepositorySessionReads(_db).read(
    _pendingGroup,
    ('pending', kind, accountId),
    () async {
      const accountRpc = 'get_my_ledger_account_pending_count';
      const countsRpc = 'get_my_ledger_pending_counts';
      final db = _db;
      if (accountId != null) {
        final count =
            await db.rpc(
                  accountRpc,
                  params: {'p_kind': kind.name, 'p_account_id': accountId},
                )
                as num;
        return Map<String, int>.unmodifiable({accountId: count.toInt()});
      }
      final rows =
          await db.rpc(countsRpc, params: {'p_kind': kind.name}) as List;
      return Map<String, int>.unmodifiable({
        for (final row in rows)
          row['account_id'] as String: (row['pending_count'] as num).toInt(),
      });
    },
  );

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

  Future<bool> canPropose(String id) =>
      RepositorySessionReads(_db).read(_group, ('can-propose', id), () async {
        return await _db.rpc(
              'can_propose_shared_ledger_change',
              params: {'p_share_id': id},
            ) ==
            true;
      });

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
    }, pendingOnly: true);
  }

  Future<void> _write(
    String rpc,
    Map<String, Object?> params, {
    bool pendingOnly = false,
  }) async {
    final client = _db;
    final reads = RepositorySessionReads(client);
    void invalidate() {
      reads.invalidate(_pendingGroup);
      // Pending submissions do not change ledger entries or totals.
      if (!pendingOnly) {
        reads.invalidate(_group);
        reads.invalidate(_homeLinksGroup);
      }
    }

    invalidate();
    try {
      await client.rpc(rpc, params: params);
    } finally {
      invalidate();
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
