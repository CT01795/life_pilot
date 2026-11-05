class AccountDeletionCursor {
  const AccountDeletionCursor(this.status, this.at, this.id);
  final String status;
  final DateTime? at;
  final String id;
  Map<String, dynamic> toJson() => {
    'status': status,
    'action_at': at?.toUtc().toIso8601String(),
    'id': id,
  };
}

class AccountDeletionRequest {
  const AccountDeletionRequest({
    required this.id,
    required this.email,
    required this.status,
    this.requestedAt,
    this.cursorAt,
  });
  final String id, email, status;
  final String? requestedAt;
  final DateTime? cursorAt;
  bool get isCancellation => status == 'cancel_pending';
  AccountDeletionCursor get cursor =>
      AccountDeletionCursor(status, cursorAt, id);
  factory AccountDeletionRequest.fromJson(Map row) {
    final id = row['id'], email = row['email'], status = row['status'];
    final at = row.containsKey('action_at')
        ? row['action_at']
        : row['cancellation_requested_at'] ?? row['requested_at'];
    if ((id is! String && id is! int) ||
        id.toString().isEmpty ||
        email is! String ||
        !{'pending', 'cancel_pending'}.contains(status) ||
        (at != null && (at is! String || DateTime.tryParse(at) == null))) {
      throw const FormatException('Invalid deletion request');
    }
    return AccountDeletionRequest(
      id: id.toString(),
      email: email,
      status: status as String,
      requestedAt: row['requested_at'] as String?,
      cursorAt: at == null ? null : DateTime.parse(at as String),
    );
  }
}

class AccountDeletionPage {
  const AccountDeletionPage({
    required this.rows,
    required this.hasMore,
    this.offsetBased = false,
  });
  static const size = 50;
  final List<AccountDeletionRequest> rows;
  final bool hasMore, offsetBased;
  factory AccountDeletionPage.fromRows(
    List<dynamic> values, {
    bool offsetBased = false,
  }) => AccountDeletionPage(
    rows: List.unmodifiable(
      values
          .take(size)
          .map((row) => AccountDeletionRequest.fromJson(row as Map)),
    ),
    hasMore: values.length > size,
    offsetBased: offsetBased,
  );
}

typedef AccountDeletionPageLoader =
    Future<AccountDeletionPage> Function({
      AccountDeletionCursor? after,
      required int offset,
    });
