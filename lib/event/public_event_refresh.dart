class PublicEventRefreshStatus {
  const PublicEventRefreshStatus({
    required this.updated,
    required this.running,
  });

  final bool updated;
  final bool running;
}

class PublicEventRefreshSummary {
  const PublicEventRefreshSummary({
    required this.attempted,
    required this.successful,
    required this.failed,
  });

  const PublicEventRefreshSummary.empty()
    : attempted = 0,
      successful = 0,
      failed = 0;

  final int attempted;
  final int successful;
  final int failed;

  bool get hasAttempts => attempted > 0;

  /// A refresh is only complete when at least half of the attempted sources
  /// succeeded. Exactly 50% is accepted; anything lower remains retryable.
  bool get hasSufficientSuccess => hasAttempts && successful * 2 >= attempted;
}

enum PublicEventRefreshExecution { performed, alreadyUpdated, running }
