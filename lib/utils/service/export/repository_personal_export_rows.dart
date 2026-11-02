import 'package:life_pilot/utils/supabase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';

/// Excel only. Cloud-to-device transfer must keep using the complete export.
class RepositoryPersonalExportRows {
  RepositoryPersonalExportRows({SupabaseClient? client})
    : client = client ?? supabase;
  final SupabaseClient client;
  static const tables = [
    'calendar_events',
    'memory_trace',
    'accounting_account',
    'accounting_detail',
    'point_record_account',
    'point_record_detail',
  ];
  static const fields = [
    'id',
    'account',
    'name',
    'type',
    'city',
    'location',
    'start_date',
    'end_date',
    'start_time',
    'end_time',
    'description',
    'date',
    'time',
    'primary_category',
    'group',
    'secondary_category',
    'title',
    'value',
    'currency',
    'main_currency',
    'balance',
    'points',
    'account_id',
  ];

  void assertOwner(String? id, String email) {
    final user = client.auth.currentUser;
    if (id == null ||
        user?.id != id ||
        user?.email?.trim().toLowerCase() != email.trim().toLowerCase()) {
      throw StateError('Export account changed');
    }
  }

  Future<List<Map<String, dynamic>>> read(String email) async {
    assertOwner(client.auth.currentUser?.id, email);
    return RepositorySessionReads(client).read(
      'excel-export',
      email.trim().toLowerCase(),
      () => _read(email),
      timeout: null,
    );
  }

  Future<List<Map<String, dynamic>>> _read(String email) async {
    final id = client.auth.currentUser?.id;
    assertOwner(id, email);
    final result = <Map<String, dynamic>>[];
    var legacy = false;
    const pageSize = 1000;
    for (var offset = 0; ; offset += pageSize) {
      assertOwner(id, email);
      Future<List<Map<String, dynamic>>> readPage(
        String function,
      ) async => await client
          .rpc(function)
          .inFilter('table_name', tables)
          .select(
            'table_name,${fields.map((field) => '$field:record->$field').join(',')}',
          )
          .order('table_name')
          .order('record->>id')
          .range(offset, offset + pageSize - 1)
          .timeout(const Duration(seconds: 30));
      List<Map<String, dynamic>> page;
      try {
        page = await readPage(
          legacy
              ? 'export_my_cloud_data_for_local'
              : 'export_my_personal_excel_rows',
        );
      } on PostgrestException catch (error) {
        // Retry only an undeployed projection, never authorization/server errors.
        if (legacy || error.code != 'PGRST202') rethrow;
        assertOwner(id, email);
        legacy = true;
        page = await readPage('export_my_cloud_data_for_local');
      }
      assertOwner(id, email);
      result.addAll(page.map((row) => Map<String, dynamic>.unmodifiable(row)));
      if (page.length < pageSize) break;
    }
    return List.unmodifiable(result);
  }
}
