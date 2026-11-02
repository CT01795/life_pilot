import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/service/export/model_personal_export_row.dart';
import 'package:life_pilot/utils/service/export/repository_personal_export_rows.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:life_pilot/utils/service/service_personal_data.dart';
import 'package:life_pilot/utils/supabase.dart';

class _Capture extends ServiceExportPlatform {
  late Uint8List bytes;
  @override
  Future<String> exportFile(String filename, Uint8List bytes) async {
    this.bytes = bytes;
    return filename;
  }
}

List<Map<String, dynamic>> fixtures() => [
  {
    'table_name': 'calendar_events',
    'id': 'c',
    'name': 'Event',
    'city': 'City',
    'start_date': '2026-11-02',
    'start_time': '17:23',
    'end_date': null,
  },
  {
    'table_name': 'memory_trace',
    'id': 'm',
    'name': 'Memory',
    'start_date': '1999-01-01',
    'description': 'historic',
  },
  {
    'table_name': 'accounting_account',
    'id': 'a',
    'name': 'Wallet',
    'main_currency': 'JPY',
    'balance': 1234.5678,
  },
  {
    'table_name': 'accounting_detail',
    'id': 'ad',
    'account_id': 'a',
    'date': '2030-01-01T17:23:00Z',
    'value': -50.25,
    'currency': 'JPY',
    'primary_category': 'uncategorized',
    'group': 'uncategorized',
    'description': 'Expense',
  },
  {
    'table_name': 'point_record_account',
    'id': 'p',
    'name': 'Points',
    'points': 55,
  },
  {
    'table_name': 'point_record_detail',
    'id': 'pd',
    'account_id': 'p',
    'date': '2030-01-01',
    'time': '17:23',
    'value': -3.25,
    'primary_category': 'uncategorized',
    'group': 'uncategorized',
    'description': 'Deduction',
  },
];

Map<String, dynamic> nested(Map<String, dynamic> row) => {
  'table_name': row['table_name'],
  'record': Map<String, dynamic>.from(row)..remove('table_name'),
};
Map<String, dynamic> expanded(Map<String, dynamic> row) => {
  'table_name': row['table_name'],
  for (final field in RepositoryPersonalExportRows.fields) field: row[field],
};

Map<String, List<List<String?>>> workbook(Uint8List bytes) => {
  for (final entry in Excel.decodeBytes(bytes).tables.entries)
    entry.key: [
      for (final row in entry.value.rows)
        [for (final cell in row) cell?.value?.toString()],
    ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final row in fixtures()) {
    test(
      '${row['table_name']} compact normalization preserves legacy keys and values',
      () {
        final compact = PersonalExportRow.fromWire(
          nested(row),
          nested: true,
          fields: RepositoryPersonalExportRows.fields,
        ).values;
        final old = PersonalExportRow.fromWire(
          expanded(row),
          nested: false,
          fields: RepositoryPersonalExportRows.fields,
        ).values;
        expect(compact, old);
        expect(compact.keys, containsAll(RepositoryPersonalExportRows.fields));
        expect(() => compact['value'] = 0, throwsUnsupportedError);
      },
    );
  }
  test(
    'unknown fields and image payloads never enter normalized Excel data',
    () {
      final row = fixtures().first;
      final wire = nested({
        ...row,
        'internal_secret': 'hidden',
        'master_graph_url': 'image',
        'sub_events': [
          {'secret': true},
        ],
      });
      final decoded = PersonalExportRow.fromWire(
        wire,
        nested: true,
        fields: RepositoryPersonalExportRows.fields,
      ).values;
      expect(decoded, expanded(row));
      expect(decoded.keys, isNot(contains('internal_secret')));
      expect(decoded.keys, isNot(contains('master_graph_url')));
    },
  );
  for (final invalid in [null, [], 'not an object']) {
    test('invalid nested record stays an error: $invalid', () {
      expect(
        () => PersonalExportRow.fromWire(
          {'table_name': 'calendar_events', 'record': invalid},
          nested: true,
          fields: RepositoryPersonalExportRows.fields,
        ),
        throwsFormatException,
      );
    });
  }

  late SupabaseClient client;
  late List<http.Request> requests;
  var legacy = false, malformed = false, wireBytes = 0;
  setUp(() async {
    legacy = false;
    malformed = false;
    wireBytes = 0;
    requests = [];
    client = SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((r) async {
        requests.add(r);
        final modern = r.url.path.endsWith('export_my_personal_excel_rows');
        if (modern && legacy) {
          return http.Response(
            jsonEncode({'code': 'PGRST202', 'message': 'missing'}),
            404,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }
        final offset = int.parse(r.url.queryParameters['offset'] ?? '0');
        final rows = offset > 0 ? <Map<String, dynamic>>[] : fixtures();
        final payload = modern
            ? malformed
                  ? [
                      {'table_name': 'calendar_events', 'record': null},
                    ]
                  : rows.map(nested).toList()
            : rows.map(expanded).toList();
        final body = jsonEncode(payload);
        wireBytes += utf8.encode(body).length;
        return http.Response(
          body,
          200,
          request: r,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    supabase = client;
    await client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'token',
        'token_type': 'bearer',
        'user': {
          'id': 'one',
          'email': 'one@example.com',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() => client.dispose());

  for (final language in ['zh', 'en', 'ja', 'ko']) {
    test(
      '$language: actual workbook cells/sheets are identical with fewer wire bytes',
      () async {
        final loc = await AppLocalizations.delegate.load(Locale(language));
        final capture = _Capture();
        await ServicePersonalData().export(
          email: 'one@example.com',
          exporter: capture,
          loc: loc,
        );
        final modernWorkbook = workbook(capture.bytes), modernBytes = wireBytes;
        expect(
          requests.every(
            (r) => r.url.queryParameters['select'] == 'table_name,record',
          ),
          isTrue,
        );
        expect(modernWorkbook, hasLength(7));
        expect(modernWorkbook.containsKey('Sheet1'), isFalse);
        legacy = true;
        wireBytes = 0;
        requests.clear();
        await ServicePersonalData().export(
          email: 'one@example.com',
          exporter: capture,
          loc: loc,
        );
        expect(workbook(capture.bytes), modernWorkbook);
        expect(modernBytes, lessThan(wireBytes));
        final successful = requests.where(
          (r) => r.url.path.endsWith('export_my_cloud_data_for_local'),
        );
        expect(successful, hasLength(2));
        expect(
          successful.first.url.queryParameters['select'],
          contains('value:record->value'),
        );
        expect(
          successful.first.url.queryParameters['select'],
          isNot(contains('master_graph_url')),
        );
      },
    );
  }
  test(
    'malformed modern response is not replaced by a complete legacy export',
    () async {
      malformed = true;
      await expectLater(
        RepositoryPersonalExportRows(client: client).read('one@example.com'),
        throwsFormatException,
      );
      expect(requests, hasLength(1));
    },
  );
}
