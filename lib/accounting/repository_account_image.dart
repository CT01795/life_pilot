import 'dart:typed_data';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/graph.dart';
import 'package:life_pilot/utils/supabase.dart';

class RepositoryAccountImage {
  const RepositoryAccountImage();

  Future<Uint8List?> read({
    required String table,
    required String accountId,
    required String owner,
  }) async {
    final client = supabase;
    final actor = client.auth.currentUser;
    if (actor?.email?.toLowerCase() != owner.toLowerCase()) return null;
    final local = LocalDataStore.instance;
    final storedLocally =
        await local.preferredLocation(owner) == DataStorageLocation.local;
    if (client.auth.currentUser?.id != actor?.id) return null;
    final row = storedLocally
        ? await local.readOnlyRow(owner: owner, resource: table, id: accountId)
        : await client
              .from(table)
              .select('master_graph_url')
              .eq('id', accountId)
              .eq('created_by', owner)
              .eq('is_valid', true)
              .maybeSingle();
    if (client.auth.currentUser?.id != actor?.id) return null;
    return decodeBase64InIsolate(row?['master_graph_url'] as String?);
  }
}
