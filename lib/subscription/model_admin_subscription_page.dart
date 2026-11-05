class AdminSubscriptionCursor {
  const AdminSubscriptionCursor(this.email, this.userId);
  final String email;
  final String userId;
}

class AdminSubscriptionSummary {
  const AdminSubscriptionSummary(
    this.email,
    this.activeEntitlements,
    this.userId,
  );
  final String email;
  final int activeEntitlements;
  final String? userId;
}

class AdminSubscriptionPage {
  const AdminSubscriptionPage({
    required this.rows,
    required this.hasMore,
    this.cursor,
  });
  static const size = 50;
  final List<AdminSubscriptionSummary> rows;
  final bool hasMore;
  final AdminSubscriptionCursor? cursor;
  factory AdminSubscriptionPage.fromRows(List<dynamic> values) {
    final rows = <AdminSubscriptionSummary>[];
    for (final value in values.take(size)) {
      if (value is! Map ||
          value['account'] is! String ||
          value['active_entitlements'] is! int ||
          (value['active_entitlements'] as int) < 0) {
        throw const FormatException('Invalid subscription summary');
      }
      final id = value['user_id'];
      if (id is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
          ).hasMatch(id)) {
        throw const FormatException('Invalid subscription cursor');
      }
      rows.add(
        AdminSubscriptionSummary(
          value['account'] as String,
          value['active_entitlements'] as int,
          id,
        ),
      );
    }
    final last = rows.isEmpty ? null : rows.last;
    return AdminSubscriptionPage(
      rows: List.unmodifiable(rows),
      hasMore: values.length > size,
      cursor: last == null
          ? null
          : AdminSubscriptionCursor(last.email, last.userId!),
    );
  }
}

typedef AdminSubscriptionPageLoader =
    Future<AdminSubscriptionPage> Function({AdminSubscriptionCursor? after});
