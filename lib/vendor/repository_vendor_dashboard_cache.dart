import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/vendor/model_vendor_account.dart';
import 'package:life_pilot/vendor/model_vendor_dashboard.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _VendorDashboardCacheState {
  Object? scope;
  DateTime? expiresAt;
  ModelVendorDashboard? value;
  int revision = 0;
  int? recentRefreshRevision;
  Future<ModelVendorDashboard?>? recentRefresh;
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
    if (state.scope != currentScope) {
      state.revision++;
      state
        ..recentRefreshRevision = null
        ..recentRefresh = null;
    }
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
    (_states[client] ??= _VendorDashboardCacheState()).revision++;
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
    (_states[client] ??= _VendorDashboardCacheState()).revision++;
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
  Future<ModelVendorDashboard?> refreshRecentSubmissions() async {
    if (read() == null) return null;
    final requestScope = scope;
    if (requestScope == null) return null;
    final state = _states[client]!;
    final active = state.recentRefresh;
    if (active != null) {
      final activeRevision = state.recentRefreshRevision;
      await active;
      if (scope != requestScope) return null;
      if (state.revision != activeRevision) {
        return refreshRecentSubmissions();
      }
      return read();
    }
    final requestRevision = state.revision;
    final now = _now();
    late final Future<ModelVendorDashboard?> request;
    request =
        Future<ModelVendorDashboard?>.sync(() async {
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
          if (scope != requestScope ||
              state.revision != requestRevision ||
              value is! List) {
            return null;
          }
          final latest = read();
          if (latest == null) return null;
          final updated = latest.withRecentSubmissions(
            value.take(5).map(VendorRecentSubmission.fromJson),
          );
          write(updated);
          return updated;
        }).whenComplete(() {
          if (identical(state.recentRefresh, request)) {
            state
              ..recentRefresh = null
              ..recentRefreshRevision = null;
          }
        });
    state
      ..recentRefreshRevision = requestRevision
      ..recentRefresh = request;
    return request;
  }
}
