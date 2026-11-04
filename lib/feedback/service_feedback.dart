import 'dart:convert';
import 'dart:typed_data';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import '../utils/logger.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/feedback/model_feedback_page.dart';

class ServiceFeedback {
  ({Object scope, DateTime date, DateTime readAt})? _historyHint;
  static final _historyRevisions = Expando<int>();

  static void _invalidateHistory(Object client) {
    _historyRevisions[client] = (_historyRevisions[client] ?? 0) + 1;
  }

  Future<FeedbackPage> loadFeedbackPage({
    required Set<String> statuses,
    FeedbackCursor? before,
  }) {
    const allowed = {'pending', 'in_progress', 'completed'};
    if (statuses.any((s) => !allowed.contains(s))) {
      return Future.error(ArgumentError('Invalid feedback status'));
    }
    if (statuses.isEmpty) {
      return Future.value(const FeedbackPage(rows: [], hasMore: false));
    }
    final selected = statuses.toList()..sort();
    final client = supabase;
    return RepositorySessionReads(client).read(
      'feedback',
      (
        'page',
        selected.join(','),
        before?.createdAt?.toUtc().toIso8601String(),
        before?.id,
      ),
      () async {
        final statusFilters = [
          for (final status in selected) 'status.eq.$status',
          if (statuses.contains('pending'))
            'and(status.is.null,or(is_ok.eq.false,is_ok.is.null))',
          if (statuses.contains('completed'))
            'and(status.is.null,is_ok.eq.true)',
        ];
        final filters = ['or(${statusFilters.join(',')})'];
        if (before != null) {
          final date = before.createdAt?.toUtc().toIso8601String();
          filters.add(
            date == null
                ? 'and(created_at.is.null,id.lt.${before.id})'
                : 'or(created_at.lt.$date,and(created_at.eq.$date,id.lt.${before.id}),created_at.is.null)',
          );
        }
        final rows = await client
            .from(TableNames.feedback)
            .select(
              'id,subject,content,created_by,created_at,is_ok,deal_by,deal_at,status',
            )
            .or('and(${filters.join(',')})')
            .order('created_at', ascending: false, nullsFirst: false)
            .order('id', ascending: false)
            .limit(FeedbackPage.size + 1);
        return FeedbackPage.fromRows(rows);
      },
    );
  }

  Future<void> sendFeedback({
    required String account,
    required String subject,
    required String content,
    List<String>? cc, // ← 改成 List<String>
    List<Uint8List>? screenshots, // ← 支援多張
  }) async {
    final screenshotBase64 = screenshots
        ?.map((bytes) => base64Encode(bytes))
        .toList();
    final client = supabase;
    final reads = RepositorySessionReads(client);
    _invalidateHistory(client);
    reads.invalidate('feedback');
    try {
      await client.from(TableNames.feedback).insert({
        'subject': subject,
        'content': content,
        'cc': cc, // text[]
        'screenshot': screenshotBase64, // text[] 或 bytea[]，依你的 schema
        Fields.createdBy: account,
        Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
        'is_ok': false,
      });
    } finally {
      _invalidateHistory(client);
      reads.invalidate('feedback');
    }
  }

  Future<List<dynamic>> loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) => RepositorySessionReads(supabase).read('feedback', (
    'list',
    dateFrom.toUtc().toIso8601String(),
    dateTo.toUtc().toIso8601String(),
  ), () => _loadFeedback(dateFrom: dateFrom, dateTo: dateTo));

  Future<List<dynamic>> _loadFeedback({
    required DateTime dateFrom,
    required DateTime dateTo,
  }) async {
    try {
      final response = await supabase
          .from(TableNames.feedback)
          .select(
            'id,subject,content,created_by,created_at,is_ok,deal_by,deal_at,status',
          )
          .gte(Fields.createdAt, dateFrom.toUtc().toIso8601String())
          .lt(Fields.createdAt, dateTo.toUtc().toIso8601String())
          .order(Fields.createdAt, ascending: false);

      return List.unmodifiable(
        response.map((row) => Map<String, dynamic>.unmodifiable(row)),
      );
    } catch (e, st) {
      logger.e('loadFeedback failed $e', stackTrace: st);
      rethrow;
    }
  }

  Future<bool> hasFeedbackBefore(DateTime before) async {
    final client = supabase;
    final scope = _historyScope(before);
    final date = await _readLatestFeedbackDate(before);
    if (scope == _historyScope(before) && identical(client, supabase)) {
      _historyHint = date == null
          ? null
          : (scope: scope, date: date, readAt: DateTime.now());
    }
    return date != null;
  }

  Future<List<String>> loadScreenshots(int id) async {
    return RepositorySessionReads(
      supabase,
    ).read('feedback', ('images', id), () => _loadScreenshots(id));
  }

  Future<List<String>> _loadScreenshots(int id) async {
    final client = supabase;
    final owner = client.auth.currentUser?.id;
    if (owner == null) throw StateError('Authentication required');
    final row = await client
        .from(TableNames.feedback)
        .select('screenshot')
        .eq('id', id)
        .maybeSingle();
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Feedback account changed');
    }
    if (row == null) throw StateError('Feedback no longer visible');
    return List<String>.unmodifiable(
      (row['screenshot'] as List? ?? const [])
          .map((value) => value as String)
          .toList(growable: false),
    );
  }

  Future<DateTime?> latestFeedbackDateBefore(DateTime before) async {
    final hint = _historyHint;
    _historyHint = null;
    if (hint != null &&
        hint.scope == _historyScope(before) &&
        DateTime.now().difference(hint.readAt) < const Duration(seconds: 15)) {
      return hint.date;
    }
    return _readLatestFeedbackDate(before);
  }

  Object _historyScope(DateTime before) {
    final client = supabase;
    return (
      client,
      client.auth.currentSession?.accessToken,
      _historyRevisions[client] ?? 0,
      before.toUtc(),
    );
  }

  Future<DateTime?> _readLatestFeedbackDate(DateTime before) {
    return RepositorySessionReads(supabase).read('feedback', (
      'latest',
      before.toUtc().toIso8601String(),
    ), () => _latestFeedbackDateBefore(before));
  }

  Future<DateTime?> _latestFeedbackDateBefore(DateTime before) async {
    final rows = await supabase
        .from(TableNames.feedback)
        .select(Fields.createdAt)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return tryParseDateTimeValue(rows.first[Fields.createdAt], toLocal: true);
  }

  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    final data = feedback.toMap();
    final client = supabase;
    final reads = RepositorySessionReads(client);
    _invalidateHistory(client);
    reads.invalidate('feedback');
    try {
      await client
          .from(TableNames.feedback)
          .update({
            'is_ok': data['is_ok'],
            'deal_by': data['deal_by'],
            'deal_at': data['deal_at'],
            'status': data['status'],
          })
          .eq(Fields.id, data[Fields.id]);
    } finally {
      _invalidateHistory(client);
      reads.invalidate('feedback');
    }
  }
}
