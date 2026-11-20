import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _VendorDashboardCacheState {
  Object? scope;
  DateTime? expiresAt;
  ModelVendorDashboard? value;
}

/// Session-scoped dashboard snapshot shared by the dashboard and submission
/// controllers. It is presentation data only; quota enforcement remains in DB.
class RepositoryVendorDashboardCache {
  RepositoryVendorDashboardCache(
    this.client, {
    DateTime Function()? now,
    this.ttl = const Duration(minutes: 2),
  }) : _now = now ?? DateTime.now;

  final SupabaseClient client;
  final DateTime Function() _now;
  final Duration ttl;
  static final _states = Expando<_VendorDashboardCacheState>();

  Object? get scope {
    final user = client.auth.currentUser;
    final token = client.auth.currentSession?.accessToken;
    return user == null || token == null
        ? null
        : (user.id, user.email?.trim().toLowerCase(), token);
  }

  ModelVendorDashboard? read() {
    final state = _states[client];
    final currentScope = scope;
    if (state == null || currentScope == null || state.scope != currentScope) {
      return null;
    }
    final expiresAt = state.expiresAt;
    if (expiresAt == null || !_now().isBefore(expiresAt)) return null;
    return state.value;
  }

  void write(ModelVendorDashboard value) {
    final currentScope = scope;
    if (currentScope == null) return;
    final state = _states[client] ??= _VendorDashboardCacheState();
    state
      ..scope = currentScope
      ..value = value
      ..expiresAt = _now().add(ttl);
  }

  void applySubmissionSaved({
    required EventItem? previous,
    required EventItem current,
    required bool attraction,
  }) {
    final cached = read();
    if (cached == null) return;
    final now = _now();
    write(
      cached.applySubmissionSaved(
        previous: previous,
        current: current,
        attraction: attraction,
        dayStart: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  void applySubmissionDeleted({
    required EventItem previous,
    required bool attraction,
  }) {
    final cached = read();
    if (cached == null) return;
    final now = _now();
    write(
      cached.applySubmissionDeleted(
        previous: previous,
        attraction: attraction,
        dayStart: DateTime(now.year, now.month, now.day),
      ),
    );
  }

  /// Refreshes only the small recent-submission list. Counters and plan data
  /// remain the locally updated snapshot, avoiding another dashboard bootstrap.
  Future<void> refreshRecentSubmissions() async {
    if (read() == null) return;
    final requestScope = scope;
    if (requestScope == null) return;
    final now = _now();
    final value = await client.rpc(
      'get_my_vendor_recent_submissions',
      params: {
        'p_day_start': DateTime(
          now.year,
          now.month,
          now.day,
        ).toUtc().toIso8601String(),
      },
    );
    if (scope != requestScope || value is! List) return;
    final latest = read();
    if (latest == null) return;
    write(
      latest.withRecentSubmissions(
        value.take(5).map(VendorRecentSubmission.fromJson),
      ),
    );
  }

  void invalidate() {
    final state = _states[client];
    if (state == null) return;
    state
      ..scope = null
      ..expiresAt = null
      ..value = null;
  }
}
