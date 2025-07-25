import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// Label for app title
  ///
  /// In en, this message translates to:
  /// **'Life Pilot'**
  String get appTitle;

  /// Label for language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'loginRelated'**
  String get loginRelated;

  /// Label for login
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// Label for login anonymously
  ///
  /// In en, this message translates to:
  /// **'Login as Guest'**
  String get loginAnonymously;

  /// Label for logout
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Label for reset password
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Label for reset password email sent
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your inbox.'**
  String get resetPasswordEmail;

  /// Label for email error
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get noEmailError;

  /// Label for email error
  ///
  /// In en, this message translates to:
  /// **'Account format error'**
  String get invalidEmail;

  /// Label for password error
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get noPasswordError;

  /// Label for reset password error
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get resetPasswordEmailNotFound;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'User or Password is wrong'**
  String get wrongUserPassword;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Too many requests'**
  String get tooManyRequests;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get networkError;

  /// Label for email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for register
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// Label for back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginError;

  /// Label for logout error
  ///
  /// In en, this message translates to:
  /// **'Logout failed. Please try again.'**
  String get logoutError;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registerError;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Email already in uUse.'**
  String get emailAlreadyInUse;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Password should be at least 6 characters'**
  String get weakPassword;

  /// Label for unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pageRelated'**
  String get pageRelated;

  /// Label for Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for Personal Event
  ///
  /// In en, this message translates to:
  /// **'Personal Event'**
  String get personal_event;

  /// Label for Recommended Event
  ///
  /// In en, this message translates to:
  /// **'Recommended Event'**
  String get recommended_event;

  /// Label for Recommended Attractions
  ///
  /// In en, this message translates to:
  /// **'Recommended Attractions'**
  String get recommended_attractions;

  /// Label for Memory Trace
  ///
  /// In en, this message translates to:
  /// **'Memory Trace'**
  String get memory_trace;

  /// Label for Account Records
  ///
  /// In en, this message translates to:
  /// **'Account Records'**
  String get account_records;

  /// Label for Points Record
  ///
  /// In en, this message translates to:
  /// **'Points Record'**
  String get points_record;

  /// Label for Game
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// Label for AI
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pageRecommendedEvent'**
  String get pageRecommendedEvent;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
