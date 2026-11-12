import 'dart:convert';
import 'dart:typed_data';
import 'package:life_pilot/feedback/model_feedback.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/feedback/model_feedback_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ServiceFeedback {
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
    final client = supabase;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Authentication required');
    final paths = <String>[];
    final reads = RepositorySessionReads(client);
    reads.invalidate('feedback');
    try {
      for (final bytes in screenshots ?? const <Uint8List>[]) {
        final path = '$userId/${const Uuid().v4()}.png';
        await client.storage
            .from('feedback-screenshots')
            .uploadBinary(
              path,
              bytes,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );
        paths.add(path);
      }
      await client.from(TableNames.feedback).insert({
        'subject': subject,
        'content': content,
        'cc': cc, // text[]
        'screenshot_paths': paths,
        Fields.createdBy: account,
        Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
        'is_ok': false,
      });
    } catch (_) {
      if (paths.isNotEmpty) {
        try {
          await client.storage.from('feedback-screenshots').remove(paths);
        } catch (_) {}
      }
      rethrow;
    } finally {
      reads.invalidate('feedback');
    }
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
        .select('screenshot_paths')
        .eq('id', id)
        .maybeSingle();
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Feedback account changed');
    }
    if (row == null) throw StateError('Feedback no longer visible');
    final paths = (row['screenshot_paths'] as List? ?? const [])
        .map(parseStringValue)
        .where((path) => path.isNotEmpty)
        .toList(growable: false);
    if (paths.isNotEmpty) {
      const concurrentDownloads = 3;
      final images = <String>[];
      for (
        var offset = 0;
        offset < paths.length;
        offset += concurrentDownloads
      ) {
        final candidateEnd = offset + concurrentDownloads;
        final end = candidateEnd < paths.length ? candidateEnd : paths.length;
        images.addAll(
          await Future.wait([
            for (final path in paths.sublist(offset, end))
              client.storage
                  .from('feedback-screenshots')
                  .download(path)
                  .then(base64Encode),
          ]),
        );
      }
      return List.unmodifiable(images);
    }
    // Legacy Base64 is queried only for rows that have not been migrated to
    // Storage. Normal rows never transfer the large historical column.
    final legacy = await client
        .from(TableNames.feedback)
        .select('screenshot')
        .eq('id', id)
        .maybeSingle();
    if (client.auth.currentUser?.id != owner) {
      throw StateError('Feedback account changed');
    }
    if (legacy == null) throw StateError('Feedback no longer visible');
    return List<String>.unmodifiable(
      (legacy['screenshot'] as List? ?? const []).map(parseStringValue),
    );
  }

  Future<void> updateFeedback({required ModelFeedback feedback}) async {
    final data = feedback.toMap();
    final client = supabase;
    final reads = RepositorySessionReads(client);
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
      reads.invalidate('feedback');
    }
  }
}
