import 'package:life_pilot/utils/const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads exact quota usage without downloading every matching record ID.
/// No completed values are cached: a read after a mutation sees fresh counts.
class RepositorySubscriptionCounts {
  const RepositorySubscriptionCounts(this.client);

  final SupabaseClient client;

  Future<List<int>> readRecommendations({
    required String account,
    required DateTime now,
  }) async {
    final owner = account.trim().toLowerCase();
    if (owner.isEmpty) throw ArgumentError.value(account, 'account');
    final today =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return Future.wait<int>([
      for (final table in [
        TableNames.recommendEvents,
        TableNames.recommendPlaces,
      ])
        client
            .from(table)
            .count(CountOption.exact)
            .ilike(Fields.account, owner)
            .or('end_date.gte.$today,start_date.gte.$today'),
    ]);
  }
}
