import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Complete transfer data, never the image-free Excel projection.
/// Yielding pages avoids retaining a second full copy of every image in memory.
class RepositoryCloudTransferExport {
  RepositoryCloudTransferExport({SupabaseClient? client})
    : client = client ?? supabase;
  final SupabaseClient client;

  Stream<List<Map<String, dynamic>>> pages(String account) async* {
    final session = client.auth.currentSession;
    if (session == null ||
        session.user.email?.trim().toLowerCase() !=
            account.trim().toLowerCase()) {
      throw StateError('Transfer account changed');
    }
    void current() {
      if (client.auth.currentUser?.id != session.user.id ||
          client.auth.currentSession?.accessToken != session.accessToken) {
        throw StateError('Transfer account changed');
      }
    }

    final seen = <String>{};
    var offset = 0;
    while (true) {
      current();
      final rawPage = await client
          .rpc('export_my_cloud_data_for_local')
          .order('table_name')
          .order('record->>id')
          .range(offset, offset + 999)
          .timeout(const Duration(seconds: 30));
      current();
      if (rawPage is! List) {
        throw const FormatException('Invalid transfer page');
      }
      final page = rawPage;
      if (page.isEmpty) return;
      final validated = <Map<String, dynamic>>[];
      for (final raw in page) {
        final table = raw['table_name'], record = raw['record'];
        if (table is! String || table.isEmpty || record is! Map) {
          throw const FormatException('Invalid transfer row');
        }
        final id = record['id'];
        if ((id is! String && id is! int) || id.toString().trim().isEmpty) {
          throw const FormatException('Invalid transfer ID');
        }
        if (!seen.add('$table::$id')) {
          throw const FormatException('Duplicate transfer row');
        }
        validated.add(Map<String, dynamic>.unmodifiable(raw));
      }
      yield List.unmodifiable(validated);
      current();
      // Probe until empty, not until <1000: projects may configure a lower API cap.
      offset += page.length;
    }
  }
}
