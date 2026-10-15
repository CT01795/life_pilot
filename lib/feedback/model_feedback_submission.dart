enum FeedbackSubmissionStatus { sent, requiredFields, failed }

/// Controller result; localized messages and navigation belong to View.
class FeedbackSubmissionResult {
  const FeedbackSubmissionResult(this.status, {this.error});
  final FeedbackSubmissionStatus status;
  final Object? error;
}
