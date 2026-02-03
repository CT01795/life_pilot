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

  /// Label for personalEvent
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalEvent;

  /// Label for recommendedEvent
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get recommendedEvent;

  /// Label for recommendedEventZero
  ///
  /// In en, this message translates to:
  /// **'No event'**
  String get recommendedEventZero;

  /// Label for recommendedAttractions
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get recommendedAttractions;

  /// Label for recommendedAttractionsZero
  ///
  /// In en, this message translates to:
  /// **'No recommended places at the moment'**
  String get recommendedAttractionsZero;

  /// Label for memoryTrace
  ///
  /// In en, this message translates to:
  /// **'Memory Trace'**
  String get memoryTrace;

  /// Label for memoryTraceZero
  ///
  /// In en, this message translates to:
  /// **'Go add some memories!'**
  String get memoryTraceZero;

  /// Label for accountRecords
  ///
  /// In en, this message translates to:
  /// **'Account Records'**
  String get accountRecords;

  /// Label for PointsRecord
  ///
  /// In en, this message translates to:
  /// **'Points Record'**
  String get pointsRecord;

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

  /// Label for Feedback
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Label for BusinessPlan
  ///
  /// In en, this message translates to:
  /// **'Business Plan'**
  String get businessPlan;

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

  /// Label for toggleView
  ///
  /// In en, this message translates to:
  /// **'Toggle View'**
  String get toggleView;

  /// Label for exportExcel
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportExcel;

  /// Label for add event
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get eventAdd;

  /// Label for add event ok
  ///
  /// In en, this message translates to:
  /// **'✅ Event added'**
  String get eventAddOk;

  /// Label for eventAddError
  ///
  /// In en, this message translates to:
  /// **'Add it repeatedly'**
  String get eventAddError;

  /// Label for memoryAdd
  ///
  /// In en, this message translates to:
  /// **'Add Memory'**
  String get memoryAdd;

  /// Label for memoryAdd ok
  ///
  /// In en, this message translates to:
  /// **'✅ Memory Added'**
  String get memoryAddOk;

  /// Label for memoryAddError
  ///
  /// In en, this message translates to:
  /// **'Do you want to add the memory again'**
  String get memoryAddError;

  /// Label for noEventsToExport
  ///
  /// In en, this message translates to:
  /// **'❌ No events to export'**
  String get noEventsToExport;

  /// Label for exportFailed
  ///
  /// In en, this message translates to:
  /// **'❌ Export failed'**
  String get exportFailed;

  /// Label for exportInProgress
  ///
  /// In en, this message translates to:
  /// **'❌ The previous file export is still in progress.'**
  String get exportInProgress;

  /// Label for exportSuccess
  ///
  /// In en, this message translates to:
  /// **'✅ Export successful'**
  String get exportSuccess;

  /// Label for notSupportExport
  ///
  /// In en, this message translates to:
  /// **'⚠️ Not support export'**
  String get notSupportExport;

  /// Label for excelColumnHeaderId
  ///
  /// In en, this message translates to:
  /// **'Activity id_______________________'**
  String get excelColumnHeaderId;

  /// Label for excelColumnHeaderMasterUrl
  ///
  /// In en, this message translates to:
  /// **'Activity url_______________________'**
  String get excelColumnHeaderMasterUrl;

  /// Label for excelColumnHeaderActivityName
  ///
  /// In en, this message translates to:
  /// **'Activity name_______________________'**
  String get excelColumnHeaderActivityName;

  /// Label for excelColumnHeaderKeywords
  ///
  /// In en, this message translates to:
  /// **'Keywords_______________________'**
  String get excelColumnHeaderKeywords;

  /// Label for excelColumnHeaderCity
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get excelColumnHeaderCity;

  /// Label for excelColumnHeaderLocation
  ///
  /// In en, this message translates to:
  /// **'Location____________________'**
  String get excelColumnHeaderLocation;

  /// Label for excelColumnHeaderFee
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get excelColumnHeaderFee;

  /// Label for excelColumnHeaderStartDate
  ///
  /// In en, this message translates to:
  /// **'Start Date__'**
  String get excelColumnHeaderStartDate;

  /// Label for excelColumnHeaderStartTime
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get excelColumnHeaderStartTime;

  /// Label for excelColumnHeaderEndDate
  ///
  /// In en, this message translates to:
  /// **'End Date__'**
  String get excelColumnHeaderEndDate;

  /// Label for excelColumnHeaderEndTime
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get excelColumnHeaderEndTime;

  /// Label for excelColumnHeaderDescription
  ///
  /// In en, this message translates to:
  /// **'Description______'**
  String get excelColumnHeaderDescription;

  /// Label for excelColumnHeaderSponsor
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get excelColumnHeaderSponsor;

  /// Label for excelColumnHeaderAgeMin
  ///
  /// In en, this message translates to:
  /// **'Min. Age'**
  String get excelColumnHeaderAgeMin;

  /// Label for excelColumnHeaderAgeMax
  ///
  /// In en, this message translates to:
  /// **'Max Age'**
  String get excelColumnHeaderAgeMax;

  /// Label for excelColumnHeaderIsFree
  ///
  /// In en, this message translates to:
  /// **'Free ?'**
  String get excelColumnHeaderIsFree;

  /// Label for excelColumnHeaderPriceMin
  ///
  /// In en, this message translates to:
  /// **'Min. Price'**
  String get excelColumnHeaderPriceMin;

  /// Label for excelColumnHeaderPriceMax
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get excelColumnHeaderPriceMax;

  /// Label for excelColumnHeaderIsOutdoor
  ///
  /// In en, this message translates to:
  /// **'Outdoor ?'**
  String get excelColumnHeaderIsOutdoor;

  /// Label for downloaded
  ///
  /// In en, this message translates to:
  /// **'✅ Downloaded'**
  String get downloaded;

  /// Label for activityName
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get activityName;

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

  /// Label for startDate
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// Label for startTime
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// Label for endDate
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// Label for endTime
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

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

  /// Label for ageMin
  ///
  /// In en, this message translates to:
  /// **'Min. Age'**
  String get ageMin;

  /// Label for ageMax
  ///
  /// In en, this message translates to:
  /// **'Max Age'**
  String get ageMax;

  /// Label for priceMin
  ///
  /// In en, this message translates to:
  /// **'Min. Price'**
  String get priceMin;

  /// Label for priceMax
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get priceMax;

  /// Label for isFree
  ///
  /// In en, this message translates to:
  /// **'Free ?'**
  String get isFree;

  /// Label for isOutdoor
  ///
  /// In en, this message translates to:
  /// **'Outdoor ?'**
  String get isOutdoor;

  /// Label for toBeDetermined
  ///
  /// In en, this message translates to:
  /// **'To Be Determined'**
  String get toBeDetermined;

  /// Label for free
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// Label for pay
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// Label for outdoor
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get outdoor;

  /// Label for indoor
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// Label for masterUrl
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get masterUrl;

  /// Label for subUrl
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get subUrl;

  /// Label for eventSaved
  ///
  /// In en, this message translates to:
  /// **'✅ Event saved'**
  String get eventSaved;

  /// Label for eventSaveError
  ///
  /// In en, this message translates to:
  /// **'Activity name cannot be empty'**
  String get eventSaveError;

  /// Label for eventAddEdit
  ///
  /// In en, this message translates to:
  /// **'Add/Edit'**
  String get eventAddEdit;

  /// Label for eventAddSub
  ///
  /// In en, this message translates to:
  /// **'Add detailed activities'**
  String get eventAddSub;

  /// Label for Detailed activities
  ///
  /// In en, this message translates to:
  /// **'Detailed activities'**
  String get eventSub;

  /// Label for save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for searchKeywords
  ///
  /// In en, this message translates to:
  /// **'Keyword (comma separated)'**
  String get searchKeywords;

  /// Label for dateClear
  ///
  /// In en, this message translates to:
  /// **'Date clear'**
  String get dateClear;

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

  /// Label for like
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// Label for dislike
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dislike;

  /// Label for eventDelete
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get eventDelete;

  /// Label for deleteOk
  ///
  /// In en, this message translates to:
  /// **'✅ Deletion completed'**
  String get deleteOk;

  /// Label for deleteError
  ///
  /// In en, this message translates to:
  /// **'❌ Delete failed'**
  String get deleteError;

  /// Label for clickHereToSeeMore
  ///
  /// In en, this message translates to:
  /// **'See more...'**
  String get clickHereToSeeMore;

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

  /// Label for speakUp
  ///
  /// In en, this message translates to:
  /// **'Speak up'**
  String get speakUp;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pagCalendar'**
  String get pagCalendar;

  /// Label for weekDaySun
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekDaySun;

  /// Label for weekDayMon
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekDayMon;

  /// Label for weekDayTue
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekDayTue;

  /// Label for weekDayWed
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekDayWed;

  /// Label for weekDayThu
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekDayThu;

  /// Label for weekDayFri
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekDayFri;

  /// Label for weekDaySat
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekDaySat;

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

  /// Label for confirmDelete
  ///
  /// In en, this message translates to:
  /// **'Confirm delete?'**
  String get confirmDelete;

  /// Label for setAlarm
  ///
  /// In en, this message translates to:
  /// **'Set alarm'**
  String get setAlarm;

  /// Label for cancelAlarm
  ///
  /// In en, this message translates to:
  /// **'Cancel alarm'**
  String get cancelAlarm;

  /// Label for setAlarmCompleted
  ///
  /// In en, this message translates to:
  /// **'✅ Set alarm completed'**
  String get setAlarmCompleted;

  /// Label for previousMonth
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Label for nextMonth
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Label for clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Label for repeatOptions
  ///
  /// In en, this message translates to:
  /// **'Repeat times'**
  String get repeatOptions;

  /// Label for repeatOptionsOnce
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get repeatOptionsOnce;

  /// Label for repeatOptionsEveryDay
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatOptionsEveryDay;

  /// Label for repeatOptionsEveryWeek
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatOptionsEveryWeek;

  /// Label for repeatOptionsEveryTwoWeeks
  ///
  /// In en, this message translates to:
  /// **'Every two weeks'**
  String get repeatOptionsEveryTwoWeeks;

  /// Label for repeatOptionsEveryMonth
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get repeatOptionsEveryMonth;

  /// Label for repeatOptionsEveryTwoMonths
  ///
  /// In en, this message translates to:
  /// **'Every two months'**
  String get repeatOptionsEveryTwoMonths;

  /// Label for repeatOptionsEveryYear
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeatOptionsEveryYear;

  /// Label for repeatOptionsEvery
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatOptionsEvery;

  /// Label for reminderOptions
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get reminderOptions;

  /// Label for reminderOptions15MinutesBefore
  ///
  /// In en, this message translates to:
  /// **'15 minutes before'**
  String get reminderOptions15MinutesBefore;

  /// Label for reminderOptions30MinutesBefore
  ///
  /// In en, this message translates to:
  /// **'30 minutes before'**
  String get reminderOptions30MinutesBefore;

  /// Label for reminderOptionsOneHourBefore
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get reminderOptionsOneHourBefore;

  /// Label for reminderOptionsDefaultSameDay8am
  ///
  /// In en, this message translates to:
  /// **'Sam day 8 am'**
  String get reminderOptionsDefaultSameDay8am;

  /// Label for reminderOptionsDefaultDayBefore8am
  ///
  /// In en, this message translates to:
  /// **'1 day before 8 am'**
  String get reminderOptionsDefaultDayBefore8am;

  /// Label for reminderOptionsTwoDaysBefore
  ///
  /// In en, this message translates to:
  /// **'2 days before'**
  String get reminderOptionsTwoDaysBefore;

  /// Label for reminderOptionsOneWeekBefore
  ///
  /// In en, this message translates to:
  /// **'1 week before'**
  String get reminderOptionsOneWeekBefore;

  /// Label for reminderOptionsTwoWeeksBefore
  ///
  /// In en, this message translates to:
  /// **'2 weeks before'**
  String get reminderOptionsTwoWeeksBefore;

  /// Label for reminderOptionsOneMonthBefore
  ///
  /// In en, this message translates to:
  /// **'1 month before'**
  String get reminderOptionsOneMonthBefore;

  /// Label for eventReminder
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get eventReminder;

  /// Label for eventReminderToday
  ///
  /// In en, this message translates to:
  /// **'Today event reminder'**
  String get eventReminderToday;

  /// Label for eventReminderDesc
  ///
  /// In en, this message translates to:
  /// **'Remind you of upcoming events'**
  String get eventReminderDesc;
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
