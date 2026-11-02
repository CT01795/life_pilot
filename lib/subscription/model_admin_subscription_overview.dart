class AdminSubscriptionOverview {
  const AdminSubscriptionOverview({
    required this.subscription,
    required this.entitlements,
  });
  final Map<String, dynamic>? subscription;
  final List<Map<String, dynamic>> entitlements;

  factory AdminSubscriptionOverview.fromJson(Map<String, dynamic> json) {
    final subscription = json['subscription'], rows = json['entitlements'];
    if ((subscription != null && subscription is! Map) ||
        rows is! List ||
        rows.any((row) => row is! Map)) {
      throw const FormatException(
        'Invalid administrator subscription overview',
      );
    }
    return AdminSubscriptionOverview(
      subscription: subscription == null
          ? null
          : Map<String, dynamic>.unmodifiable(subscription as Map),
      entitlements: List.unmodifiable(
        rows.map((row) => Map<String, dynamic>.unmodifiable(row as Map)),
      ),
    );
  }
}
