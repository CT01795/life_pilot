import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/supabase.dart';
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
        request.completeError(error, stack);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> writeCloud(
    String table,
    String id,
    Map<String, Object?> fields,
  ) async => supabase
      .from(table)
      .update(fields)
      .eq('id', id)
      .eq('is_valid', true)
      .select('id');

  static Future<Map<String, Object?>> imageFields(Uint8List bytes) async => {
    'master_graph_url': base64Encode(bytes),
    'thumbnail_base64': await _thumbnailBase64(bytes),
  };

  static Future<String?> _thumbnailBase64(Uint8List bytes) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        final landscape = descriptor.width >= descriptor.height;
        final longestEdge = landscape ? descriptor.width : descriptor.height;
        final edges = {
          for (final cap in [320, 256, 192, 144, 112, 96, 64])
            longestEdge < cap ? longestEdge : cap,
        };
        for (final edge in edges) {
          final codec = await descriptor.instantiateCodec(
            targetWidth: landscape ? edge : null,
            targetHeight: landscape ? null : edge,
          );
          try {
            final frame = await codec.getNextFrame();
            try {
              final png = await frame.image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              if (png != null && png.lengthInBytes <= 49152) {
                return base64Encode(
                  png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
                );
              }
            } finally {
              frame.image.dispose();
            }
          } finally {
            codec.dispose();
          }
        }
        return null;
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  static int? _pngLongestEdge(String? thumbnail) {
    if (thumbnail == null ||
        thumbnail.length < 32 ||
        !thumbnail.startsWith('iVBORw0KGgo')) {
      return null;
    }
    try {
      final header = ByteData.sublistView(
        base64Decode(thumbnail.substring(0, 32)),
      );
      final width = header.getUint32(16);
      final height = header.getUint32(20);
      return width >= height ? width : height;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _backfillCloudThumbnail(
    SupabaseClient client,
    String actorId,
    String table,
    String id,
    String original,
    Uint8List bytes,
    String? previous,
  ) async {
    try {
      final thumbnail = await _thumbnailBase64(bytes);
      if (thumbnail == null ||
          client.auth.currentUser?.id != actorId ||
          (previous != null && (_pngLongestEdge(thumbnail) ?? 0) <= 96)) {
        return;
      }
      await client.rpc(
        'upgrade_my_ledger_thumbnail',
        params: {
          'p_resource': table,
          'p_account_id': id,
          'p_original_hash': sha256.convert(utf8.encode(original)).toString(),
          'p_thumbnail': thumbnail,
          'p_previous_hash': previous == null
              ? null
              : sha256.convert(utf8.encode(previous)).toString(),
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
    final row = await client.rpc(
      'read_my_shared_ledger_image',
      params: {'p_share_id': id, 'p_thumbnail': thumbnail},
    );
    if (client.auth.currentUser?.id != actor) return null;
    if (row is! Map ||
        !row.containsKey('image') ||
        (row['image'] != null && row['image'] is! String)) {
      throw const FormatException('Invalid shared ledger image');
    }
    return decodeBase64InIsolate(row['image'] as String?);
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
    final row = storedLocally
        ? await local.readOnlyRow(owner: owner, resource: table, id: accountId)
        : await readCloud(thumbnail ? column : '$column,thumbnail_base64');
    if (client.auth.currentUser?.id != actor?.id) return null;
    final encoded = row?[column] as String?;
    final bytes = decodeBase64InIsolate(encoded);
    if (client.auth.currentUser?.id != actor?.id) return null;
    final previous = row?['thumbnail_base64'] as String?;
    if (!storedLocally &&
        !thumbnail &&
        actor != null &&
        encoded != null &&
        bytes != null &&
        (previous == null || _pngLongestEdge(previous) == 96)) {
      unawaited(
        _backfillCloudThumbnail(
          client,
          actor.id,
          table,
          accountId,
          encoded,
          bytes,
          previous,
        ),
      );
    }
    return bytes;
  }
}
