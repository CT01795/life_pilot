import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/repository_optional_json_rpc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RepositoryAccountImage {
  const RepositoryAccountImage();
  static final _thumbnailQueues =
      Expando<
        Map<(String, String?, String), Map<String, Completer<String?>>>
      >();
  static final _thumbnailInFlight =
      Expando<Map<(String, String?, String, String), Future<String?>>>();

  static Future<String?> _queueThumbnail(
    SupabaseClient client,
    String token,
    String? table,
    String owner,
    String id,
  ) {
    final key = (token, table, owner);
    final requestKey = (token, table, owner, id);
    final active = _thumbnailInFlight[client] ??= {};
    final existing = active[requestKey];
    if (existing != null) return existing;
    final queues = _thumbnailQueues[client] ??= {};
    final pending = queues.putIfAbsent(key, () {
      Timer.run(() {
        final batch = queues.remove(key)!;
        final ids = batch.keys.toList(growable: false);
        for (var offset = 0; offset < ids.length; offset += 30) {
          unawaited(
            _readThumbnailBatch(client, key, {
              for (final id in ids.skip(offset).take(30)) id: batch[id]!,
            }),
          );
        }
      });
      return {};
    });
    final request = pending.putIfAbsent(id, Completer<String?>.new).future;
    return active[requestKey] = request.whenComplete(() {
      active.remove(requestKey);
    });
  }

  static Future<void> _readThumbnailBatch(
    SupabaseClient client,
    (String, String?, String) key,
    Map<String, Completer<String?>> requests,
  ) async {
    final (token, table, owner) = key;
    bool current() => client.auth.currentSession?.accessToken == token;
    try {
      if (table == null) {
        final thumbnails = current()
            ? await client.rpc(
                'read_my_shared_ledger_thumbnails',
                params: {'p_share_ids': requests.keys.toList(growable: false)},
              )
            : const <String, dynamic>{};
        if (thumbnails is! Map) {
          throw const FormatException('Invalid shared thumbnails');
        }
        for (final entry in requests.entries) {
          entry.value.complete(
            current() ? thumbnails[entry.key] as String? : null,
          );
        }
        return;
      }
      final rows = current()
          ? await client
                .from(table)
                .select('id,thumbnail_base64')
                .inFilter('id', requests.keys.toList(growable: false))
                .eq('created_by', owner)
                .eq('is_valid', true)
          : const <Map<String, dynamic>>[];
      final thumbnails = {
        for (final row in rows) row['id']: row['thumbnail_base64'] as String?,
      };
      for (final entry in requests.entries) {
        entry.value.complete(current() ? thumbnails[entry.key] : null);
      }
    } catch (error, stack) {
      for (final request in requests.values.where((r) => !r.isCompleted)) {
        if (error is PostgrestException && error.code == '42703') {
          request.complete(null);
        } else {
          request.completeError(error, stack);
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> writeCloud(
    String table,
    String id,
    Map<String, Object?> fields,
  ) async {
    final client = supabase;
    final actor = client.auth.currentUser?.id;
    Future<List<Map<String, dynamic>>> save(Map<String, Object?> data) => client
        .from(table)
        .update(data)
        .eq('id', id)
        .eq('is_valid', true)
        .select('id');
    try {
      return await save(fields);
    } on PostgrestException catch (error) {
      if ((error.code != '42703' && error.code != 'PGRST204') ||
          client.auth.currentUser?.id != actor) {
        rethrow;
      }
      return save({'master_graph_url': fields['master_graph_url']});
    }
  }

  static Future<Map<String, Object?>> imageFields(Uint8List bytes) async => {
    'master_graph_url': base64Encode(bytes),
    'thumbnail_base64': await _thumbnailBase64(bytes),
  };

  static Future<String?> _thumbnailBase64(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final codec = await descriptor.instantiateCodec(
          targetWidth: descriptor.width >= descriptor.height ? 96 : null,
          targetHeight: descriptor.height > descriptor.width ? 96 : null,
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final png = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            return png == null
                ? null
                : base64Encode(
                    png.buffer.asUint8List(
                      png.offsetInBytes,
                      png.lengthInBytes,
                    ),
                  );
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  static Future<void> _backfillCloudThumbnail(
    SupabaseClient client,
    String actorId,
    String table,
    String id,
    String original,
    Uint8List bytes,
  ) async {
    try {
      final thumbnail = await _thumbnailBase64(bytes);
      if (thumbnail == null || client.auth.currentUser?.id != actorId) return;
      await RepositoryOptionalJsonRpc(client).read(
        'backfill_my_ledger_thumbnail',
        params: {
          'p_resource': table,
          'p_account_id': id,
          'p_original_hash': sha256.convert(utf8.encode(original)).toString(),
          'p_thumbnail': thumbnail,
        },
      );
    } catch (_) {
      // Backfill is optional; a corrupt image or failed write must not block reads.
    }
  }

  Future<Uint8List?> readShared(String id, {required bool thumbnail}) async {
    final client = supabase;
    final actor = client.auth.currentUser?.id;
    if (actor == null) return null;
    final token = client.auth.currentSession?.accessToken;
    if (thumbnail) {
      if (token == null) return null;
      final encoded = await _queueThumbnail(client, token, null, actor, id);
      if (client.auth.currentSession?.accessToken != token) return null;
      return decodeBase64InIsolate(encoded);
    }
    final row = await RepositoryOptionalJsonRpc(client).read(
      'read_my_shared_ledger_image',
      params: {'p_share_id': id, 'p_thumbnail': thumbnail},
    );
    if (client.auth.currentUser?.id != actor) return null;
    return decodeBase64InIsolate(row?['image'] as String?);
  }

  Future<Uint8List?> read({
    required String table,
    required String accountId,
    required String owner,
    bool thumbnail = false,
    DataStorageLocation? storage,
  }) async {
    final client = supabase;
    final actor = client.auth.currentUser;
    if (actor?.email?.toLowerCase() != owner.toLowerCase()) return null;
    final local = LocalDataStore.instance;
    final storedLocally =
        (storage ?? await local.preferredLocation(owner)) ==
        DataStorageLocation.local;
    if (client.auth.currentUser?.id != actor?.id) return null;
    final token = client.auth.currentSession?.accessToken;
    if (thumbnail && !storedLocally && token != null) {
      final encoded = await _queueThumbnail(
        client,
        token,
        table,
        owner,
        accountId,
      );
      if (client.auth.currentSession?.accessToken != token) return null;
      return decodeBase64InIsolate(encoded);
    }
    final column = thumbnail ? 'thumbnail_base64' : 'master_graph_url';
    Future<Map<String, dynamic>?> readCloud(String projection) => client
        .from(table)
        .select(projection)
        .eq('id', accountId)
        .eq('created_by', owner)
        .eq('is_valid', true)
        .maybeSingle();
    Map<String, dynamic>? row;
    try {
      row = storedLocally
          ? await local.readOnlyRow(
              owner: owner,
              resource: table,
              id: accountId,
            )
          : await readCloud(thumbnail ? column : '$column,thumbnail_base64');
    } on PostgrestException catch (error) {
      if (thumbnail && error.code == '42703') return null;
      if (storedLocally ||
          thumbnail ||
          error.code != '42703' ||
          client.auth.currentUser?.id != actor?.id) {
        rethrow;
      }
      row = await readCloud(column);
    }
    if (client.auth.currentUser?.id != actor?.id) return null;
    final encoded = row?[column] as String?;
    final bytes = decodeBase64InIsolate(encoded);
    if (client.auth.currentUser?.id != actor?.id) return null;
    if (!storedLocally &&
        !thumbnail &&
        actor != null &&
        encoded != null &&
        bytes != null &&
        row!.containsKey('thumbnail_base64') &&
        row['thumbnail_base64'] == null) {
      unawaited(
        _backfillCloudThumbnail(
          client,
          actor.id,
          table,
          accountId,
          encoded,
          bytes,
        ),
      );
    }
    return bytes;
  }
}
