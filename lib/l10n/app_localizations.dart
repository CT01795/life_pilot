import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
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
    Locale('ja'),
    Locale('ko'),
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
  /// **'  Login  '**
  String get login;

  /// Label for login anonymously
  ///
  /// In en, this message translates to:
  /// **'Guest Login'**
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
  /// **'  Register  '**
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
  /// **'Personal'**
  String get personal_event;

  /// Label for Recommended Event
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get recommended_event;

  /// Label for no Recommended Event
  ///
  /// In en, this message translates to:
  /// **'No event'**
  String get recommended_event_zero;

  /// Label for Recommended Attractions
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
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

  /// Label for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Label for Toggle View
  ///
  /// In en, this message translates to:
  /// **'Toggle View'**
  String get toggle_view;

  /// Label for export excel
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export_excel;

  /// Label for add event
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get event_add;

  /// Label for add event ok
  ///
  /// In en, this message translates to:
  /// **'✅ Event added'**
  String get event_add_ok;

  /// Label for no_events_to_export
  ///
  /// In en, this message translates to:
  /// **'❌ No events to export'**
  String get no_events_to_export;

  /// Label for export_failed
  ///
  /// In en, this message translates to:
  /// **'❌ Export failed'**
  String get export_failed;

  /// Label for export_success
  ///
  /// In en, this message translates to:
  /// **'✅ Export successful'**
  String get export_success;

  /// Label for not_support_export
  ///
  /// In en, this message translates to:
  /// **'⚠️ Not support export'**
  String get not_support_export;

  /// Label for excel_column_header_activity_name
  ///
  /// In en, this message translates to:
  /// **'Activity name_______________________'**
  String get excel_column_header_activity_name;

  /// Label for excel_column_header_keywords
  ///
  /// In en, this message translates to:
  /// **'Keywords_______________________'**
  String get excel_column_header_keywords;

  /// Label for excel_column_header_city
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get excel_column_header_city;

  /// Label for excel_column_header_location
  ///
  /// In en, this message translates to:
  /// **'Location____________________'**
  String get excel_column_header_location;

  /// Label for excel_column_header_fee
  ///
  /// In en, this message translates to:
  /// **'fee'**
  String get excel_column_header_fee;

  /// Label for excel_column_header_start_date
  ///
  /// In en, this message translates to:
  /// **'Start Date__'**
  String get excel_column_header_start_date;

  /// Label for excel_column_header_start_time
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get excel_column_header_start_time;

  /// Label for excel_column_header_end_date
  ///
  /// In en, this message translates to:
  /// **'End Date__'**
  String get excel_column_header_end_date;

  /// Label for excel_column_header_end_time
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get excel_column_header_end_time;

  /// Label for excel_column_header_description
  ///
  /// In en, this message translates to:
  /// **'Description______'**
  String get excel_column_header_description;

  /// Label for excel_column_header_sponsor
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get excel_column_header_sponsor;

  /// Label for downloaded
  ///
  /// In en, this message translates to:
  /// **'✅ Downloaded'**
  String get downloaded;

  /// Label for activity_name
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get activity_name;

  /// Label for keywords
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get keywords;

  /// Label for city
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Label for location
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Label for fee
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// Label for start_date
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get start_date;

  /// Label for start_time
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get start_time;

  /// Label for end_date
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get end_date;

  /// Label for end_time
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get end_time;

  /// Label for description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Label for sponsor
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// Label for master_url
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get master_url;

  /// Label for sub_url
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get sub_url;

  /// Label for event_saved
  ///
  /// In en, this message translates to:
  /// **'✅ Event saved'**
  String get event_saved;

  /// Label for event_save_error
  ///
  /// In en, this message translates to:
  /// **'Activity name cannot be empty'**
  String get event_save_error;

  /// Label for event_add_edit
  ///
  /// In en, this message translates to:
  /// **'Add/Edit'**
  String get event_add_edit;

  /// Label for event_add_sub
  ///
  /// In en, this message translates to:
  /// **'Add detailed activities'**
  String get event_add_sub;

  /// Label for Detailed activities
  ///
  /// In en, this message translates to:
  /// **'Detailed activities'**
  String get event_sub;

  /// Label for save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for search_keywords
  ///
  /// In en, this message translates to:
  /// **'Keyword (blank separated)'**
  String get search_keywords;

  /// Label for date_clear
  ///
  /// In en, this message translates to:
  /// **'Date clear'**
  String get date_clear;

  /// Label for event_add_tp_plan_error
  ///
  /// In en, this message translates to:
  /// **'Add it repeatedly'**
  String get event_add_tp_plan_error;

  /// Label for add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Label for edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Label for review
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// Label for cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Label for delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for event_delete
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get event_delete;

  /// Label for delete_ok
  ///
  /// In en, this message translates to:
  /// **'✅ Deletion completed'**
  String get delete_ok;

  /// Label for delete_error
  ///
  /// In en, this message translates to:
  /// **'❌ Delete failed'**
  String get delete_error;

  /// Label for click_here_to_see_more
  ///
  /// In en, this message translates to:
  /// **'See more...'**
  String get click_here_to_see_more;

  /// Label for close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Label for url
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// Label for speak
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get speak;

  /// Label for speak_up
  ///
  /// In en, this message translates to:
  /// **'Speak up'**
  String get speak_up;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pagCalendar'**
  String get pagCalendar;

  /// Label for week_day_sun
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get week_day_sun;

  /// Label for week_day_mon
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get week_day_mon;

  /// Label for week_day_tue
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get week_day_tue;

  /// Label for week_day_wed
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get week_day_wed;

  /// Label for week_day_thu
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get week_day_thu;

  /// Label for week_day_fri
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get week_day_fri;

  /// Label for week_day_sat
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get week_day_sat;

  /// Label for year
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// Label for month
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// Label for confirm
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Label for confirm_delete
  ///
  /// In en, this message translates to:
  /// **'Confirm delete?'**
  String get confirm_delete;

  /// Label for set_alarm
  ///
  /// In en, this message translates to:
  /// **'Set alarm'**
  String get set_alarm;

  /// Label for cancel_alarm
  ///
  /// In en, this message translates to:
  /// **'Cancel alarm'**
  String get cancel_alarm;

  /// Label for set_alarm_completed
  ///
  /// In en, this message translates to:
  /// **'✅ Set alarm completed'**
  String get set_alarm_completed;

  /// Label for previous_month
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previous_month;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Label for next_month
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get next_month;

  /// Label for clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Label for repeat_options
  ///
  /// In en, this message translates to:
  /// **'Repeat times'**
  String get repeat_options;

  /// Label for repeat_options_once
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get repeat_options_once;

  /// Label for repeat_options_every_day
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeat_options_every_day;

  /// Label for repeat_options_every_week
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeat_options_every_week;

  /// Label for repeat_options_every_two_weeks
  ///
  /// In en, this message translates to:
  /// **'Every two weeks'**
  String get repeat_options_every_two_weeks;

  /// Label for repeat_options_every_month
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeat_options_every_month;

  /// Label for repeat_options_every_two_months
  ///
  /// In en, this message translates to:
  /// **'Every two months'**
  String get repeat_options_every_two_months;

  /// Label for repeat_options_every_year
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeat_options_every_year;

  /// Label for repeat_options_every
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeat_options_every;

  /// Label for reminder_options
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminder_options;

  /// Label for reminder_options_15_minutes_before
  ///
  /// In en, this message translates to:
  /// **'15 minutes before'**
  String get reminder_options_15_minutes_before;

  /// Label for reminder_options_30_minutes_before
  ///
  /// In en, this message translates to:
  /// **'30 minutes before'**
  String get reminder_options_30_minutes_before;

  /// Label for reminder_options_1_hour_before
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get reminder_options_1_hour_before;

  /// Label for reminder_options_default_same_day_8am
  ///
  /// In en, this message translates to:
  /// **'Sam day 8 am'**
  String get reminder_options_default_same_day_8am;

  /// Label for reminder_options_default_day_before_8am
  ///
  /// In en, this message translates to:
  /// **'1 day before 8 am'**
  String get reminder_options_default_day_before_8am;

  /// Label for reminder_options_2_days_before
  ///
  /// In en, this message translates to:
  /// **'2 days before'**
  String get reminder_options_2_days_before;

  /// Label for reminder_options_1_week_before
  ///
  /// In en, this message translates to:
  /// **'1 week before'**
  String get reminder_options_1_week_before;

  /// Label for reminder_options_2_weeks_before
  ///
  /// In en, this message translates to:
  /// **'2 weeks before'**
  String get reminder_options_2_weeks_before;

  /// Label for reminder_options_1_month_before
  ///
  /// In en, this message translates to:
  /// **'1 month before'**
  String get reminder_options_1_month_before;

  /// Label for event_reminder
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get event_reminder;

  /// Label for event_reminder_today
  ///
  /// In en, this message translates to:
  /// **'Today event reminder'**
  String get event_reminder_today;

  /// Label for event_reminder_desc
  ///
  /// In en, this message translates to:
  /// **'Remind you of upcoming events'**
  String get event_reminder_desc;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ja': return AppLocalizationsJa();
    case 'ko': return AppLocalizationsKo();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
