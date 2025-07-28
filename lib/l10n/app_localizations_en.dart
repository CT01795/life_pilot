// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Life Pilot';

  @override
  String get language => 'Language';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get login => '  Login  ';

  @override
  String get loginAnonymously => 'Guest Login';

  @override
  String get logout => 'Logout';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordEmail => 'Password reset email sent. Please check your inbox.';

  @override
  String get noEmailError => 'Please enter your email address.';

  @override
  String get invalidEmail => 'Account format error';

  @override
  String get noPasswordError => 'Please enter your password.';

  @override
  String get resetPasswordEmailNotFound => 'Account not found';

  @override
  String get wrongUserPassword => 'User or Password is wrong';

  @override
  String get tooManyRequests => 'Too many requests';

  @override
  String get networkError => 'Network error';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get register => '  Register  ';

  @override
  String get back => 'Back';

  @override
  String get loginError => 'Login failed. Please try again.';

  @override
  String get logoutError => 'Logout failed. Please try again.';

  @override
  String get registerError => 'Registration failed. Please try again.';

  @override
  String get emailAlreadyInUse => 'Email already in uUse.';

  @override
  String get weakPassword => 'Password should be at least 6 characters';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => 'Settings';

  @override
  String get personal_event => 'Personal';

  @override
  String get recommended_event => 'Event';

  @override
  String get recommended_attractions => 'Attractions';

  @override
  String get memory_trace => 'Memory Trace';

  @override
  String get account_records => 'Account Records';

  @override
  String get points_record => 'Points Record';

  @override
  String get game => 'Game';

  @override
  String get ai => 'AI';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';
}
