class ErrorFields {
  static const String loginError = 'loginError';
  static const String registerError = 'registerError';
  static const String logoutError = 'logoutError';
  static const String noEmailError = 'noEmailError';
  static const String noPasswordError = 'noPasswordError';
  static const String unexpectedError = 'Unexpected error';
  static const String authError = 'Auth Error';
  static const String userNotFoundError = 'user-not-found';
  static const String wrongPasswordError = 'wrong-password';
  static const String invalidCredentialError = 'invalid-credential';
  static const String wrongUserPassword = 'wrongUserPassword';
  static const String tooManyRequestsError = 'too-many-requests';
  static const String networkRequestFailedError = 'network-request-failed';
  static const String invalidEmailError = 'invalid-email';
  static const String emailAlreadyInUseError = 'email-already-in-use';
  static const String weakPasswordError = 'weak-password';
  static const String resetPasswordEmailNotFoundError = 'resetPasswordEmailNotFound';
  static const String repeatOptions = 'repeat_options';
  static const String reminderOptions = 'reminder_options';
}

enum RepeatRule {
  once,
  everyDay,
  everyWeek,
  everyTwoWeeks,
  everyMonth,
  everyTwoMonths,
  everyYear,
}

extension RepeatRuleExtension on RepeatRule {
  String key() {
    switch (this) {
      case RepeatRule.once:
        return 'once';
      case RepeatRule.everyDay:
        return 'every_day';
      case RepeatRule.everyWeek:
        return 'every_week';
      case RepeatRule.everyTwoWeeks:
        return 'every_two_weeks';
      case RepeatRule.everyMonth:
        return 'every_month';
      case RepeatRule.everyTwoMonths:
        return 'every_two_months';
      case RepeatRule.everyYear:
        return 'every_year';
    }
  }

  static RepeatRule fromKey(String? key) {
    if(key == null ){
      return RepeatRule.once;
    }
    switch (key) {
      case 'every_day':
        return RepeatRule.everyDay;
      case 'every_week':
        return RepeatRule.everyWeek;
      case 'every_two_weeks':
        return RepeatRule.everyTwoWeeks;
      case 'every_month':
        return RepeatRule.everyMonth;
      case 'every_two_months':
        return RepeatRule.everyTwoMonths;
      case 'every_year':
        return RepeatRule.everyYear;
      default:
        return RepeatRule.once;
    }
  }

  /// 取得下一個日期
  DateTime getNextDate(DateTime date) {
    switch (this) {
      case RepeatRule.everyDay:
      case RepeatRule.once: // 預設 return 原日期 + 1
        return date.add(const Duration(days: 1));
      case RepeatRule.everyWeek:
        return date.add(const Duration(days: 7));
      case RepeatRule.everyTwoWeeks:
        return date.add(const Duration(days: 14));
      case RepeatRule.everyMonth:
        return DateTime(date.year, date.month + 1, date.day);
      case RepeatRule.everyTwoMonths:
        return DateTime(date.year, date.month + 2, date.day);
      case RepeatRule.everyYear:
        return DateTime(date.year + 1, date.month, date.day);
    }
  }
}
