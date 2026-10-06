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

  /// Label for accessDenied
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get accessDenied;

  /// Label for activityName
  ///
  /// In en, this message translates to:
  /// **'Activity name'**
  String get activityName;

  /// Label for add
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Label for ageMax
  ///
  /// In en, this message translates to:
  /// **'Max Age'**
  String get ageMax;

  /// Label for ageMin
  ///
  /// In en, this message translates to:
  /// **'Min. Age'**
  String get ageMin;

  /// Label for AI
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get ai;

  /// Shown when alarm settings cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not update the reminder. Please try again later'**
  String get alarmUpdateFailed;

  /// Label for allCities
  ///
  /// In en, this message translates to:
  /// **'All cities'**
  String get allCities;

  /// Label for alreadyStarted
  ///
  /// In en, this message translates to:
  /// **'Already started'**
  String get alreadyStarted;

  /// Amount column title
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get amountLabel;

  /// Label for answerExample
  ///
  /// In en, this message translates to:
  /// **'Answer example'**
  String get answerExample;

  /// Label for answerHere
  ///
  /// In en, this message translates to:
  /// **'Answer here'**
  String get answerHere;

  /// Label for answerOptions
  ///
  /// In en, this message translates to:
  /// **'Answer options'**
  String get answerOptions;

  /// Label for answerOptionsHint
  ///
  /// In en, this message translates to:
  /// **'Separate options with commas'**
  String get answerOptionsHint;

  /// Label for app title
  ///
  /// In en, this message translates to:
  /// **'Life Pilot'**
  String get appTitle;

  /// Label for ask administrator
  ///
  /// In en, this message translates to:
  /// **'Ask the administrator'**
  String get askAdministrator;

  /// Label for ask administrator description
  ///
  /// In en, this message translates to:
  /// **'Open your email app and send a request. The administrator will reply after handling it.'**
  String get askAdministratorDescription;

  /// Label for back
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Label for blocklyEditor
  ///
  /// In en, this message translates to:
  /// **'Blockly Editor'**
  String get blocklyEditor;

  /// Label for cancel
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Label for cancelAlarm
  ///
  /// In en, this message translates to:
  /// **'Cancel alarm'**
  String get cancelAlarm;

  /// Label for captureScreen
  ///
  /// In en, this message translates to:
  /// **'Capture screen'**
  String get captureScreen;

  /// Label for categoryLabel
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// Label for check
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// Label for checkPath
  ///
  /// In en, this message translates to:
  /// **'Check the path'**
  String get checkPath;

  /// Label for choosePhoto
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// Label for clear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

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

  /// Action for completing a schedule and recording its review
  ///
  /// In en, this message translates to:
  /// **'Complete & review'**
  String get completeAndReview;

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

  /// No description provided for @congratulationsScore.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! Score: {score}'**
  String congratulationsScore(num score);

  /// Label for continuing an action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Label for continueLevel
  ///
  /// In en, this message translates to:
  /// **'Continue level {level}'**
  String continueLevel(int level);

  /// Label for correctAnswer
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get correctAnswer;

  /// Label for coverPhotoOptional
  ///
  /// In en, this message translates to:
  /// **'Cover photo (optional)'**
  String get coverPhotoOptional;

  /// Label for create
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Label for dataCleanupAction
  ///
  /// In en, this message translates to:
  /// **'Review and clean up'**
  String get dataCleanupAction;

  /// Label for dataCleanupAll
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get dataCleanupAll;

  /// Label for dataCleanupAllConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete all personal data in the selected storage? This cannot be undone.'**
  String get dataCleanupAllConfirm;

  /// Label for dataCleanupConfirmTitle
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get dataCleanupConfirmTitle;

  /// Label for dataCleanupExcess
  ///
  /// In en, this message translates to:
  /// **'Remove excess'**
  String get dataCleanupExcess;

  /// Label for dataCleanupExcessConfirm
  ///
  /// In en, this message translates to:
  /// **'Delete only records above the current allowance? This cannot be undone.'**
  String get dataCleanupExcessConfirm;

  /// Label for dataCleanupFailed
  ///
  /// In en, this message translates to:
  /// **'Data cleanup failed'**
  String get dataCleanupFailed;

  /// Label for dataCleanupNoOverage
  ///
  /// In en, this message translates to:
  /// **'No cloud data currently exceeds the allowance.'**
  String get dataCleanupNoOverage;

  /// Label for dataCleanupSuccess
  ///
  /// In en, this message translates to:
  /// **'Data cleanup completed'**
  String get dataCleanupSuccess;

  /// Label for dataCleanupTargetEmail
  ///
  /// In en, this message translates to:
  /// **'User email (blank means yourself)'**
  String get dataCleanupTargetEmail;

  /// Label for dataCleanupTitle
  ///
  /// In en, this message translates to:
  /// **'Data cleanup'**
  String get dataCleanupTitle;

  /// Label for dataClearLocalAction
  ///
  /// In en, this message translates to:
  /// **'Clear device data'**
  String get dataClearLocalAction;

  /// Label for dataClearLocalConfirm
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes all personal data on this device and cannot be undone. You can then try switching to cloud storage. Continue?'**
  String get dataClearLocalConfirm;

  /// Label for dataClearLocalFailed
  ///
  /// In en, this message translates to:
  /// **'Could not clear device data. Try again later.'**
  String get dataClearLocalFailed;

  /// Label for dataClearLocalSuccess
  ///
  /// In en, this message translates to:
  /// **'Device data cleared'**
  String get dataClearLocalSuccess;

  /// Label for dataClearLocalTitle
  ///
  /// In en, this message translates to:
  /// **'Clear device data'**
  String get dataClearLocalTitle;

  /// Label for dataMoveToLocal
  ///
  /// In en, this message translates to:
  /// **'Move cloud data to this device'**
  String get dataMoveToLocal;

  /// Label for dataMoveToLocalConfirm
  ///
  /// In en, this message translates to:
  /// **'Cloud data will be copied and verified before it is removed from the cloud. It will then be visible only on this device, browser, and browser profile. It will not automatically appear elsewhere, and removing the app or clearing site data may permanently delete it. Continue?'**
  String get dataMoveToLocalConfirm;

  /// Label for dataMoveToLocalFailed
  ///
  /// In en, this message translates to:
  /// **'Some data could not be moved. Cloud originals were retained.'**
  String get dataMoveToLocalFailed;

  /// Label for dataMoveToLocalSuccess
  ///
  /// In en, this message translates to:
  /// **'Cloud data was moved to this device.'**
  String get dataMoveToLocalSuccess;

  /// Label for dateClear
  ///
  /// In en, this message translates to:
  /// **'Date clear'**
  String get dateClear;

  /// Unit label for days
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// Label for delete
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Label for deleteError
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get deleteError;

  /// No description provided for @deleteNumberedItem.
  ///
  /// In en, this message translates to:
  /// **'Delete item {number}, {name}?'**
  String deleteNumberedItem(int number, String name);

  /// Label for deleteOk
  ///
  /// In en, this message translates to:
  /// **'✅ Deletion completed'**
  String get deleteOk;

  /// Label for description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Button that discards unsaved form changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// Label for dislike
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dislike;

  /// Label for downloaded
  ///
  /// In en, this message translates to:
  /// **'✅ Downloaded'**
  String get downloaded;

  /// Label for edit
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Label for email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Email already in uUse.'**
  String get emailAlreadyInUse;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Email not confirmed'**
  String get emailNotConfirmed;

  /// Email verification rate limit error
  ///
  /// In en, this message translates to:
  /// **'Too many verification emails have been requested. Please try again later.'**
  String get emailRateLimitExceeded;

  /// Label for endDate
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDate;

  /// Label for endsToday
  ///
  /// In en, this message translates to:
  /// **'Already started, ends today'**
  String get endsToday;

  /// Label for endTime
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get endTime;

  /// Label for englishRpgAdventureTitle
  ///
  /// In en, this message translates to:
  /// **'English RPG Adventure'**
  String get englishRpgAdventureTitle;

  /// Label for enterAnswer
  ///
  /// In en, this message translates to:
  /// **'Enter your answer'**
  String get enterAnswer;

  /// Label for excelColumnHeaderActivityName
  ///
  /// In en, this message translates to:
  /// **'Activity name_______________________'**
  String get excelColumnHeaderActivityName;

  /// Label for excelColumnHeaderAgeMax
  ///
  /// In en, this message translates to:
  /// **'Max Age'**
  String get excelColumnHeaderAgeMax;

  /// Label for excelColumnHeaderAgeMin
  ///
  /// In en, this message translates to:
  /// **'Min. Age'**
  String get excelColumnHeaderAgeMin;

  /// Label for excelColumnHeaderDescription
  ///
  /// In en, this message translates to:
  /// **'Description______'**
  String get excelColumnHeaderDescription;

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

  /// Label for excelColumnHeaderFee
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get excelColumnHeaderFee;

  /// Label for excelColumnHeaderId
  ///
  /// In en, this message translates to:
  /// **'Activity id_______________________'**
  String get excelColumnHeaderId;

  /// Label for excelColumnHeaderIsFree
  ///
  /// In en, this message translates to:
  /// **'Free ?'**
  String get excelColumnHeaderIsFree;

  /// Label for excelColumnHeaderIsOutdoor
  ///
  /// In en, this message translates to:
  /// **'Outdoor ?'**
  String get excelColumnHeaderIsOutdoor;

  /// Label for excelColumnHeaderKeywords
  ///
  /// In en, this message translates to:
  /// **'Keywords_______________________'**
  String get excelColumnHeaderKeywords;

  /// Label for excelColumnHeaderMasterUrl
  ///
  /// In en, this message translates to:
  /// **'Activity url_______________________'**
  String get excelColumnHeaderMasterUrl;

  /// Label for excelColumnHeaderPriceMax
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get excelColumnHeaderPriceMax;

  /// Label for excelColumnHeaderPriceMin
  ///
  /// In en, this message translates to:
  /// **'Min. Price'**
  String get excelColumnHeaderPriceMin;

  /// Label for excelColumnHeaderSponsor
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get excelColumnHeaderSponsor;

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

  /// Shown when an external website or map cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. Please try again later'**
  String get externalLinkOpenFailed;

  /// Label for fee
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// Label for free
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// Label for go
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get go;

  /// Label for hint
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hint;

  /// Label for indoor
  ///
  /// In en, this message translates to:
  /// **'Indoor'**
  String get indoor;

  /// Label for email error
  ///
  /// In en, this message translates to:
  /// **'Account format error'**
  String get invalidEmail;

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

  /// Label for keywords
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get keywords;

  /// Label for like
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// Label for loading
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Label for loadingSections
  ///
  /// In en, this message translates to:
  /// **'Loading sections...'**
  String get loadingSections;

  /// Label for manualEntry
  ///
  /// In en, this message translates to:
  /// **'Manual entry'**
  String get manualEntry;

  /// Label for masterUrl
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get masterUrl;

  /// Label for month
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// Tooltip for additional actions
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your network and try again.'**
  String get networkError;

  /// Label for next
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Next available one-hour schedule window
  ///
  /// In en, this message translates to:
  /// **'No schedule today from {startTime} to {endTime}'**
  String nextFreeHour(String startTime, String endTime);

  /// Label for nextMonth
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get nextMonth;

  /// Label for noData
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// Label for email error
  ///
  /// In en, this message translates to:
  /// **'Please enter your email address.'**
  String get noEmailError;

  /// Label for noInfoAvailable
  ///
  /// In en, this message translates to:
  /// **'No information available.'**
  String get noInfoAvailable;

  /// Label for noPipes
  ///
  /// In en, this message translates to:
  /// **'No pipes'**
  String get noPipes;

  /// Label for notFilled
  ///
  /// In en, this message translates to:
  /// **'Not filled in yet'**
  String get notFilled;

  /// Label for notSupportUpload
  ///
  /// In en, this message translates to:
  /// **'⚠️ Not support upload'**
  String get notSupportUpload;

  /// Label for ongoingUntil
  ///
  /// In en, this message translates to:
  /// **'Ongoing until {date}'**
  String ongoingUntil(String date);

  /// Label for openChatGPT
  ///
  /// In en, this message translates to:
  /// **'Open ChatGPT'**
  String get openChatGPT;

  /// Label for outdoor
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get outdoor;

  /// Label for parsing
  ///
  /// In en, this message translates to:
  /// **'Parsing'**
  String get parsing;

  /// Label for pay
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// Label for postText
  ///
  /// In en, this message translates to:
  /// **'Post the full text'**
  String get postText;

  /// Label for previous
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Label for previousMonth
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get previousMonth;

  /// No description provided for @priceEarningsRatio.
  ///
  /// In en, this message translates to:
  /// **'P/E: {value}'**
  String priceEarningsRatio(String value);

  /// Label for priceMax
  ///
  /// In en, this message translates to:
  /// **'Max Price'**
  String get priceMax;

  /// Label for priceMin
  ///
  /// In en, this message translates to:
  /// **'Min. Price'**
  String get priceMin;

  /// Label for published content delete admin only
  ///
  /// In en, this message translates to:
  /// **'Published content can only be deleted by an administrator. You can edit it; after saving, it returns to pending review.'**
  String get publishedContentDeleteAdminOnly;

  /// Label for published submission
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publishedSubmission;

  /// Label for published submission tooltip
  ///
  /// In en, this message translates to:
  /// **'This information is public and can be viewed by everyone.'**
  String get publishedSubmissionTooltip;

  /// Registration success message
  ///
  /// In en, this message translates to:
  /// **'Registration successful.'**
  String get registrationSuccessful;

  /// No description provided for @relativeStrengthIndex.
  ///
  /// In en, this message translates to:
  /// **'RSI: {value}'**
  String relativeStrengthIndex(String value);

  /// Label for repeatOptions
  ///
  /// In en, this message translates to:
  /// **'Repeat times'**
  String get repeatOptions;

  /// Label for repeatOptionsEvery
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatOptionsEvery;

  /// Label for repeatOptionsEveryDay
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get repeatOptionsEveryDay;

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

  /// Label for repeatOptionsEveryTwoWeeks
  ///
  /// In en, this message translates to:
  /// **'Every two weeks'**
  String get repeatOptionsEveryTwoWeeks;

  /// Label for repeatOptionsEveryWeek
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get repeatOptionsEveryWeek;

  /// Label for repeatOptionsEveryYear
  ///
  /// In en, this message translates to:
  /// **'Every year'**
  String get repeatOptionsEveryYear;

  /// Label for repeatOptionsOnce
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get repeatOptionsOnce;

  /// Label for replacePhoto
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replacePhoto;

  /// Label for requiredField
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// Label for restart
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Label for review
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// Label for save
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Label for scrambledWords
  ///
  /// In en, this message translates to:
  /// **'Words to rearrange'**
  String get scrambledWords;

  /// Hint identifying a vertically scrollable list area
  ///
  /// In en, this message translates to:
  /// **'Scroll within this area'**
  String get scrollThisArea;

  /// Label for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Label for searchKeywords
  ///
  /// In en, this message translates to:
  /// **'Keyword (comma separated)'**
  String get searchKeywords;

  /// Label for secondaryCategoryLabel
  ///
  /// In en, this message translates to:
  /// **'Subcategory'**
  String get secondaryCategoryLabel;

  /// Label for setAlarm
  ///
  /// In en, this message translates to:
  /// **'Set alarm'**
  String get setAlarm;

  /// Label for setAlarmCompleted
  ///
  /// In en, this message translates to:
  /// **'✅ Set alarm completed'**
  String get setAlarmCompleted;

  /// Label for speak
  ///
  /// In en, this message translates to:
  /// **'Voice input'**
  String get speak;

  /// Label for speakingText
  ///
  /// In en, this message translates to:
  /// **'Text to speak'**
  String get speakingText;

  /// Label for speakingTitle
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get speakingTitle;

  /// Label for speakUp
  ///
  /// In en, this message translates to:
  /// **'Speak up'**
  String get speakUp;

  /// Label for sponsor
  ///
  /// In en, this message translates to:
  /// **'Sponsor'**
  String get sponsor;

  /// Label for startDate
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDate;

  /// Label for startsInDays
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} days'**
  String startsInDays(int count);

  /// Label for startsToday
  ///
  /// In en, this message translates to:
  /// **'Starts today'**
  String get startsToday;

  /// Label for startsTomorrow
  ///
  /// In en, this message translates to:
  /// **'Starts tomorrow'**
  String get startsTomorrow;

  /// Label for startTime
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// Label for statusNotStarted
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statusNotStarted;

  /// Label for subUrl
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get subUrl;

  /// Label for switchToList
  ///
  /// In en, this message translates to:
  /// **'Switch to list'**
  String get switchToList;

  /// Label for toBeDetermined
  ///
  /// In en, this message translates to:
  /// **'To Be Determined'**
  String get toBeDetermined;

  /// Label for today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Title for the integrated daily dashboard overview
  ///
  /// In en, this message translates to:
  /// **'Today\'s Life Overview'**
  String get todayLifeOverview;

  /// Hint for opening sections from the daily overview
  ///
  /// In en, this message translates to:
  /// **'See your schedule, money, and points together. Tap an item for details.'**
  String get todayLifeOverviewHint;

  /// Label for toggleView
  ///
  /// In en, this message translates to:
  /// **'Toggle View'**
  String get toggleView;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get tooManyRequests;

  /// Total amount of the selected account
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Label for twoOptionsRequired
  ///
  /// In en, this message translates to:
  /// **'Enter at least two answer options'**
  String get twoOptionsRequired;

  /// Label for unableToLoadDocument
  ///
  /// In en, this message translates to:
  /// **'Unable to load this document.'**
  String get unableToLoadDocument;

  /// Label for unknown error
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Label for unpublished submission
  ///
  /// In en, this message translates to:
  /// **'Not public yet'**
  String get unpublishedSubmission;

  /// Label for unpublished submission tooltip
  ///
  /// In en, this message translates to:
  /// **'This information is awaiting review and is currently visible only to you and administrators.'**
  String get unpublishedSubmissionTooltip;

  /// Confirmation shown before leaving an edited form
  ///
  /// In en, this message translates to:
  /// **'Your changes have not been saved. Discard them?'**
  String get unsavedChangesPrompt;

  /// Label for uploadCsv
  ///
  /// In en, this message translates to:
  /// **'Upload Csv'**
  String get uploadExcel;

  /// Label for uploadFailed
  ///
  /// In en, this message translates to:
  /// **'❌ Upload failed'**
  String get uploadFailed;

  /// Label for uploadInProgress
  ///
  /// In en, this message translates to:
  /// **'❌ The previous file upload is still in progress.'**
  String get uploadInProgress;

  /// Label for uploadSuccess
  ///
  /// In en, this message translates to:
  /// **'✅ Upload successful'**
  String get uploadSuccess;

  /// Label for url
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get url;

  /// Label for weekDayFri
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekDayFri;

  /// Label for weekDayMon
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekDayMon;

  /// Label for weekDaySat
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekDaySat;

  /// Label for weekDaySun
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekDaySun;

  /// Label for weekDayThu
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekDayThu;

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

  /// Label for wordSearchTitle
  ///
  /// In en, this message translates to:
  /// **'Word Search'**
  String get wordSearchTitle;

  /// Label for year
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// Label for account security
  ///
  /// In en, this message translates to:
  /// **'Account security'**
  String get accountSecurity;

  /// No description provided for @adminPasswordHelpBody.
  ///
  /// In en, this message translates to:
  /// **'Hello, I cannot sign in to Life Pilot. Please help with my password change.\n\nAccount: {account}\n\nPlease reply to this email after the request has been handled.'**
  String adminPasswordHelpBody(String account);

  /// No description provided for @adminPasswordHelpEmailUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The email app could not be opened. Please email {email}.'**
  String adminPasswordHelpEmailUnavailable(String email);

  /// Label for admin password help opened
  ///
  /// In en, this message translates to:
  /// **'Your email app is open. Review the message and send it.'**
  String get adminPasswordHelpOpened;

  /// Label for admin password help subject
  ///
  /// In en, this message translates to:
  /// **'Life Pilot password change request'**
  String get adminPasswordHelpSubject;

  /// Label for admin password reset description
  ///
  /// In en, this message translates to:
  /// **'Enter the requester\'s account email to create a temporary password. Reply to the user and ask them to change it immediately after signing in.'**
  String get adminPasswordResetDescription;

  /// Label for admin password reset failed
  ///
  /// In en, this message translates to:
  /// **'The temporary password could not be created. Try again later.'**
  String get adminPasswordResetFailed;

  /// Label for admin password reset send
  ///
  /// In en, this message translates to:
  /// **'Create temporary password'**
  String get adminPasswordResetSend;

  /// Label for admin password reset title
  ///
  /// In en, this message translates to:
  /// **'Help a user reset their password'**
  String get adminPasswordResetTitle;

  /// Label for admin password reset user email
  ///
  /// In en, this message translates to:
  /// **'User email'**
  String get adminPasswordResetUserEmail;

  /// Label for admin password reset user not found
  ///
  /// In en, this message translates to:
  /// **'No user was found for this email.'**
  String get adminPasswordResetUserNotFound;

  /// Label for admin temporary password copied
  ///
  /// In en, this message translates to:
  /// **'Temporary password copied.'**
  String get adminTemporaryPasswordCopied;

  /// Label for admin temporary password copy
  ///
  /// In en, this message translates to:
  /// **'Copy temporary password'**
  String get adminTemporaryPasswordCopy;

  /// No description provided for @adminTemporaryPasswordCreated.
  ///
  /// In en, this message translates to:
  /// **'A temporary password was created for {email}.'**
  String adminTemporaryPasswordCreated(String email);

  /// Label for admin temporary password instruction
  ///
  /// In en, this message translates to:
  /// **'Copy and reply with it, then ask the user to change it in Account security immediately after signing in.'**
  String get adminTemporaryPasswordInstruction;

  /// Label for admin temporary password
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get adminTemporaryPasswordLabel;

  /// Label for change password
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// Label for change password failed
  ///
  /// In en, this message translates to:
  /// **'Password update failed. Check your current password and try again.'**
  String get changePasswordFailed;

  /// Label for change password successful
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated.'**
  String get changePasswordSuccessful;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Label for current password
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// Label for current password incorrect
  ///
  /// In en, this message translates to:
  /// **'The current password is incorrect.'**
  String get currentPasswordIncorrect;

  /// Tooltip for hiding a password
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

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

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again.'**
  String get loginError;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'loginRelated'**
  String get loginRelated;

  /// Label for logout
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// Label for logout confirmation
  ///
  /// In en, this message translates to:
  /// **'Log out of the current account?'**
  String get logoutConfirmation;

  /// Label for logout error
  ///
  /// In en, this message translates to:
  /// **'Logout failed. Please try again.'**
  String get logoutError;

  /// Label for moduleAuthorization
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get moduleAuthorization;

  /// Label for moduleAuthorizationDescription
  ///
  /// In en, this message translates to:
  /// **'Choose the extra features available to a user. Home and the feature menu update together.'**
  String get moduleAuthorizationDescription;

  /// Label for moduleAuthorizationLoadFailed
  ///
  /// In en, this message translates to:
  /// **'Could not load feature access. Check the account or try again.'**
  String get moduleAuthorizationLoadFailed;

  /// Label for moduleAuthorizationNoAccess
  ///
  /// In en, this message translates to:
  /// **'No extra features are enabled.'**
  String get moduleAuthorizationNoAccess;

  /// Label for moduleAuthorizationNotDeployed
  ///
  /// In en, this message translates to:
  /// **'Feature access is not deployed. Run the authorization SQL in Supabase first.'**
  String get moduleAuthorizationNotDeployed;

  /// Label for moduleAuthorizationSaved
  ///
  /// In en, this message translates to:
  /// **'Feature access updated.'**
  String get moduleAuthorizationSaved;

  /// Label for moduleAuthorizationSaveFailed
  ///
  /// In en, this message translates to:
  /// **'Feature access was not updated correctly. Search again and retry.'**
  String get moduleAuthorizationSaveFailed;

  /// Label for moduleAuthorizationSearchFirst
  ///
  /// In en, this message translates to:
  /// **'Enter and search for a user email first.'**
  String get moduleAuthorizationSearchFirst;

  /// Label for moduleAuthorizationUserNotFound
  ///
  /// In en, this message translates to:
  /// **'No user was found for that email address.'**
  String get moduleAuthorizationUserNotFound;

  /// Label for new password
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// Label for password error
  ///
  /// In en, this message translates to:
  /// **'Please enter your password.'**
  String get noPasswordError;

  /// Label for reset password error
  ///
  /// In en, this message translates to:
  /// **'The system cannot find a valid [verification credential], or the credential has expired.'**
  String get noRecoverySession;

  /// Label for password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Label for password does not meet policy
  ///
  /// In en, this message translates to:
  /// **'The new password does not meet the security requirements. Add letters, numbers, or symbols and try again.'**
  String get passwordDoesNotMeetPolicy;

  /// Label for password help description
  ///
  /// In en, this message translates to:
  /// **'If you forgot your current password, reset it by verification email or ask the administrator for help.'**
  String get passwordHelpDescription;

  /// Label for password help title
  ///
  /// In en, this message translates to:
  /// **'Other reset options'**
  String get passwordHelpTitle;

  /// Password confirmation mismatch error
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// Label for password must be different
  ///
  /// In en, this message translates to:
  /// **'The new password must be different from the current password.'**
  String get passwordMustBeDifferent;

  /// Label for password reauthentication required
  ///
  /// In en, this message translates to:
  /// **'For security, reset your password through email verification first.'**
  String get passwordReauthenticationRequired;

  /// Label for password recovery choice description
  ///
  /// In en, this message translates to:
  /// **'Reset it yourself using a verification email, or email the administrator for help.'**
  String get passwordRecoveryChoiceDescription;

  /// Label for password recovery choice title
  ///
  /// In en, this message translates to:
  /// **'Choose a reset method'**
  String get passwordRecoveryChoiceTitle;

  /// Message shown after a successful password update
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in with your new password.'**
  String get passwordUpdateSuccessful;

  /// Label for register
  ///
  /// In en, this message translates to:
  /// **'  Register  '**
  String get register;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registerError;

  /// Registration success message when email verification is required
  ///
  /// In en, this message translates to:
  /// **'Registration successful. Please verify your email before signing in.'**
  String get registrationVerificationRequired;

  /// Label for reset by email verification
  ///
  /// In en, this message translates to:
  /// **'Reset by verification email'**
  String get resetByEmailVerification;

  /// Label for reset by email verification description
  ///
  /// In en, this message translates to:
  /// **'We will email you a secure link so you can set a new password.'**
  String get resetByEmailVerificationDescription;

  /// Label for reset password
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Password reset email resend countdown
  ///
  /// In en, this message translates to:
  /// **'Retry in {seconds}s'**
  String resetPasswordCooldown(int seconds);

  /// Label for reset password email sent
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent. Please check your inbox.'**
  String get resetPasswordEmail;

  /// Label for reset password error
  ///
  /// In en, this message translates to:
  /// **'Account not found'**
  String get resetPasswordEmailNotFound;

  /// Label for reset password error
  ///
  /// In en, this message translates to:
  /// **'Reset password failed. Please try again.'**
  String get resetPasswordError;

  /// Tooltip for showing a password
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Label for update password
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// Label for register error
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters.'**
  String get weakPassword;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'User or Password is wrong'**
  String get wrongUserPassword;

  /// Shown when a dashboard section cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Could not load this information. Please try again later'**
  String get dashboardLoadFailed;

  /// Shown when a dashboard selection cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting. Please try again later'**
  String get dashboardSettingSaveFailed;

  /// Label for Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Hint for discovering events or places when there is no schedule today
  ///
  /// In en, this message translates to:
  /// **'Nothing planned today. Start with an event or place that interests you.'**
  String get homeInsightDiscover;

  /// Hint for when the day is ready for review
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule is connected to memories, money, and points for one-step review.'**
  String get homeInsightReadyForReview;

  /// Home insight for conflicting schedules
  ///
  /// In en, this message translates to:
  /// **'{count} schedules overlap today or tomorrow. Consider adjusting your plan first.'**
  String homeInsightResolveConflicts(int count);

  /// Home insight for ended unfinished schedules
  ///
  /// In en, this message translates to:
  /// **'{count} ended schedules still need review today. Do not let important tasks slip away.'**
  String homeInsightReviewOverdue(int count);

  /// Compact hint for the integrated journey completion workflow
  ///
  /// In en, this message translates to:
  /// **'Complete a schedule and record memories, money, and points together'**
  String get homeJourneyReviewHint;

  /// Label for language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Label for language Chinese
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// Label for language English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Label for language Japanese
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// Label for language Korean
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pageRelated'**
  String get pageRelated;

  /// Label for pageSelectorTooltip
  ///
  /// In en, this message translates to:
  /// **'Function menu'**
  String get pageSelectorTooltip;

  /// Label for Settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for userMenuButton
  ///
  /// In en, this message translates to:
  /// **'User Menu'**
  String get userMenuButton;

  /// Account deletion request is only available in cloud mode
  ///
  /// In en, this message translates to:
  /// **'Account deletion requests are available in cloud mode only. Switch the storage location to cloud before submitting a request.'**
  String get accountDeletionCloudOnly;

  /// Label for adminPricingAccountingQuota
  ///
  /// In en, this message translates to:
  /// **'Accounting records'**
  String get adminPricingAccountingQuota;

  /// Label for adminPricingAnswerDays
  ///
  /// In en, this message translates to:
  /// **'Answer history days'**
  String get adminPricingAnswerDays;

  /// Label for adminPricingCalendarQuota
  ///
  /// In en, this message translates to:
  /// **'Calendar records'**
  String get adminPricingCalendarQuota;

  /// Label for adminPricingCreate
  ///
  /// In en, this message translates to:
  /// **'Create version'**
  String get adminPricingCreate;

  /// Label for adminPricingCreated
  ///
  /// In en, this message translates to:
  /// **'New pricing version created; existing benefits are unchanged'**
  String get adminPricingCreated;

  /// No description provided for @adminPricingCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save the pricing version: {error}'**
  String adminPricingCreateFailed(String error);

  /// No description provided for @adminPricingDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This is only allowed when no subscription or entitlement uses it.'**
  String adminPricingDeleteConfirmation(String name);

  /// Label for adminPricingDeleted
  ///
  /// In en, this message translates to:
  /// **'Pricing version deleted.'**
  String get adminPricingDeleted;

  /// Label for adminPricingDeleteInUse
  ///
  /// In en, this message translates to:
  /// **'This pricing version is still used by a subscription or entitlement and cannot be deleted.'**
  String get adminPricingDeleteInUse;

  /// Label for adminPricingDeleteTitle
  ///
  /// In en, this message translates to:
  /// **'Delete pricing version'**
  String get adminPricingDeleteTitle;

  /// Label for adminPricingEffectiveDate
  ///
  /// In en, this message translates to:
  /// **'Effective date'**
  String get adminPricingEffectiveDate;

  /// Label for adminPricingGameQuota
  ///
  /// In en, this message translates to:
  /// **'Custom questions'**
  String get adminPricingGameQuota;

  /// Label for adminPricingImageQuota
  ///
  /// In en, this message translates to:
  /// **'Images (MB)'**
  String get adminPricingImageQuota;

  /// Label for adminPricingLocalZeroUnlimited
  ///
  /// In en, this message translates to:
  /// **'For Local Plus, 0 in a quota field means unlimited.'**
  String get adminPricingLocalZeroUnlimited;

  /// Label for adminPricingMemoryQuota
  ///
  /// In en, this message translates to:
  /// **'Memories'**
  String get adminPricingMemoryQuota;

  /// Label for adminPricingPointQuota
  ///
  /// In en, this message translates to:
  /// **'Point records'**
  String get adminPricingPointQuota;

  /// Label for adminPricingQuarterlyPrice
  ///
  /// In en, this message translates to:
  /// **'Quarterly price (TWD)'**
  String get adminPricingQuarterlyPrice;

  /// Label for adminPricingRequired
  ///
  /// In en, this message translates to:
  /// **'Enter a version name and all numbers'**
  String get adminPricingRequired;

  /// Label for adminPricingShareQuota
  ///
  /// In en, this message translates to:
  /// **'Calendar shares'**
  String get adminPricingShareQuota;

  /// Label for adminPricingSubtitle
  ///
  /// In en, this message translates to:
  /// **'Applies to future payments and add-ons only'**
  String get adminPricingSubtitle;

  /// Label for adminPricingTitle
  ///
  /// In en, this message translates to:
  /// **'Create user pricing version'**
  String get adminPricingTitle;

  /// Label for admin pricing update
  ///
  /// In en, this message translates to:
  /// **'Update version'**
  String get adminPricingUpdate;

  /// Label for adminPricingUpdated
  ///
  /// In en, this message translates to:
  /// **'User pricing version updated; existing subscription snapshots are unchanged'**
  String get adminPricingUpdated;

  /// Label for adminPricingVersionHint
  ///
  /// In en, this message translates to:
  /// **'Example: 2026-Q4'**
  String get adminPricingVersionHint;

  /// Label for adminPricingVersionName
  ///
  /// In en, this message translates to:
  /// **'Version name'**
  String get adminPricingVersionName;

  /// Label for adminSubscriptionAddQuota
  ///
  /// In en, this message translates to:
  /// **'Add quota without replacing current benefits'**
  String get adminSubscriptionAddQuota;

  /// Label for adminSubscriptionAddQuotaHint
  ///
  /// In en, this message translates to:
  /// **'The new quota is added to unexpired quota'**
  String get adminSubscriptionAddQuotaHint;

  /// Label for adminSubscriptionCloud
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get adminSubscriptionCloud;

  /// Delete all user subscription settings
  ///
  /// In en, this message translates to:
  /// **'Delete all subscription and quota settings'**
  String get adminSubscriptionDeleteAll;

  /// Delete subscription confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete the subscription and quota settings for {email}? The user\'s data will not be deleted.'**
  String adminSubscriptionDeleteConfirmation(String email);

  /// Subscription deletion success
  ///
  /// In en, this message translates to:
  /// **'Subscription and quota settings deleted.'**
  String get adminSubscriptionDeleted;

  /// Confirm deleting one allowance
  ///
  /// In en, this message translates to:
  /// **'Delete only the {version} allowance? Other allowances and user data will be kept.'**
  String adminSubscriptionDeleteEntitlementConfirmation(String version);

  /// Delete subscription confirmation title
  ///
  /// In en, this message translates to:
  /// **'Delete subscription settings'**
  String get adminSubscriptionDeleteTitle;

  /// Label for adminSubscriptionEmail
  ///
  /// In en, this message translates to:
  /// **'User email'**
  String get adminSubscriptionEmail;

  /// One allowance deleted
  ///
  /// In en, this message translates to:
  /// **'This allowance was deleted. Other allowances were kept.'**
  String get adminSubscriptionEntitlementDeleted;

  /// Heading for individual user allowances
  ///
  /// In en, this message translates to:
  /// **'Created allowances'**
  String get adminSubscriptionEntitlements;

  /// Label for adminSubscriptionExpiry
  ///
  /// In en, this message translates to:
  /// **'Benefit expiry'**
  String get adminSubscriptionExpiry;

  /// Admin subscription extension action
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get adminSubscriptionExtend;

  /// Admin subscription extension action
  ///
  /// In en, this message translates to:
  /// **'Extend 90 days'**
  String get adminSubscriptionExtend90Days;

  /// Admin subscription extension success
  ///
  /// In en, this message translates to:
  /// **'Subscription extended by 90 days.'**
  String get adminSubscriptionExtended;

  /// Admin subscription extension success
  ///
  /// In en, this message translates to:
  /// **'Subscription extended by {days} days.'**
  String adminSubscriptionExtendedDays(int days);

  /// Number of days for an admin subscription extension
  ///
  /// In en, this message translates to:
  /// **'Extension days'**
  String get adminSubscriptionExtensionDays;

  /// Label for adminSubscriptionFree
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get adminSubscriptionFree;

  /// Label for adminSubscriptionInactiveWarning
  ///
  /// In en, this message translates to:
  /// **'The account and cloud data are removed after 3 months without changes.'**
  String get adminSubscriptionInactiveWarning;

  /// Invalid admin subscription extension days
  ///
  /// In en, this message translates to:
  /// **'Enter a number from 1 to 3650.'**
  String get adminSubscriptionInvalidExtensionDays;

  /// Subscription loaded for editing
  ///
  /// In en, this message translates to:
  /// **'The current subscription is ready to edit and save.'**
  String get adminSubscriptionLoadedForEditing;

  /// Label for adminSubscriptionLocal
  ///
  /// In en, this message translates to:
  /// **'Local unlimited'**
  String get adminSubscriptionLocal;

  /// Require a lookup before managing a subscription
  ///
  /// In en, this message translates to:
  /// **'Search for the user first.'**
  String get adminSubscriptionLookupRequired;

  /// Label for adminSubscriptionMultiplier
  ///
  /// In en, this message translates to:
  /// **'Quota multiplier'**
  String get adminSubscriptionMultiplier;

  /// Label for adminSubscriptionNoExpiry
  ///
  /// In en, this message translates to:
  /// **'The free plan has no expiry date'**
  String get adminSubscriptionNoExpiry;

  /// Message for adminSubscriptionNoPricing
  ///
  /// In en, this message translates to:
  /// **'Create a pricing version first'**
  String get adminSubscriptionNoPricing;

  /// Label for adminSubscriptionNote
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get adminSubscriptionNote;

  /// No user subscription was found
  ///
  /// In en, this message translates to:
  /// **'No subscription found'**
  String get adminSubscriptionNotFound;

  /// Prompt to create after an empty lookup
  ///
  /// In en, this message translates to:
  /// **'You can create a new subscription for this user.'**
  String get adminSubscriptionNotFoundCreate;

  /// Label for adminSubscriptionPaid
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get adminSubscriptionPaid;

  /// Label for adminSubscriptionPlan
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get adminSubscriptionPlan;

  /// Label for adminSubscriptionPricingVersion
  ///
  /// In en, this message translates to:
  /// **'Pricing version'**
  String get adminSubscriptionPricingVersion;

  /// Label for adminSubscriptionSave
  ///
  /// In en, this message translates to:
  /// **'Save subscription'**
  String get adminSubscriptionSave;

  /// Label for adminSubscriptionSaved
  ///
  /// In en, this message translates to:
  /// **'Subscription saved'**
  String get adminSubscriptionSaved;

  /// No description provided for @adminSubscriptionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String adminSubscriptionSaveFailed(String error);

  /// Label for adminSubscriptionStoragePlan
  ///
  /// In en, this message translates to:
  /// **'Storage plan'**
  String get adminSubscriptionStoragePlan;

  /// Label for adminSubscriptionSubtitle
  ///
  /// In en, this message translates to:
  /// **'Apply the pricing and quota purchased'**
  String get adminSubscriptionSubtitle;

  /// No description provided for @adminSubscriptionTimes.
  ///
  /// In en, this message translates to:
  /// **'{count}×'**
  String adminSubscriptionTimes(int count);

  /// Label for adminSubscriptionTitle
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get adminSubscriptionTitle;

  /// User was not found while managing a subscription
  ///
  /// In en, this message translates to:
  /// **'User account not found'**
  String get adminSubscriptionUserNotFound;

  /// Label for admin vendor pricing created
  ///
  /// In en, this message translates to:
  /// **'Organizer pricing version created.'**
  String get adminVendorPricingCreated;

  /// Label for admin vendor pricing subtitle
  ///
  /// In en, this message translates to:
  /// **'Future purchases use the latest effective version; existing entitlements keep their snapshot.'**
  String get adminVendorPricingSubtitle;

  /// Label for admin vendor pricing title
  ///
  /// In en, this message translates to:
  /// **'Create vendor pricing version'**
  String get adminVendorPricingTitle;

  /// Label for admin vendor pricing updated
  ///
  /// In en, this message translates to:
  /// **'Organizer pricing version updated.'**
  String get adminVendorPricingUpdated;

  /// Label for admin vendor subscription saved
  ///
  /// In en, this message translates to:
  /// **'Organizer subscription saved.'**
  String get adminVendorSubscriptionSaved;

  /// Label for admin vendor subscription subtitle
  ///
  /// In en, this message translates to:
  /// **'Assign a pricing version, allowance multiplier and expiry date to an organizer account.'**
  String get adminVendorSubscriptionSubtitle;

  /// Label for admin vendor subscription title
  ///
  /// In en, this message translates to:
  /// **'Manage organizer subscription'**
  String get adminVendorSubscriptionTitle;

  /// Calendar sharing quota error
  ///
  /// In en, this message translates to:
  /// **'You have reached the calendar sharing limit. Please remove an existing share or upgrade your plan.'**
  String get calendarInvitationQuotaExceeded;

  /// Label for dataCleanupCloudExplanation
  ///
  /// In en, this message translates to:
  /// **'Review current cloud overages, then remove only the excess or all personal cloud data.'**
  String get dataCleanupCloudExplanation;

  /// Label for dataStorageCloud
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get dataStorageCloud;

  /// Label for dataStorageCloudWarning
  ///
  /// In en, this message translates to:
  /// **'Cloud data is available across devices and is subject to your plan limits.'**
  String get dataStorageCloudWarning;

  /// Label for dataStorageLocal
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get dataStorageLocal;

  /// Shown when local storage is not included in the user's plan
  ///
  /// In en, this message translates to:
  /// **'Complete Device Plus payment and wait for admin activation before switching.'**
  String get dataStorageLocalPlanRequired;

  /// Label for dataStorageLocalWarning
  ///
  /// In en, this message translates to:
  /// **'Local data is visible only on this device, browser, and browser profile. It will not automatically appear on another device, browser, or profile. Removing the app or clearing site or browser data may permanently delete it. It can be moved to the cloud when it fits your plan limits.'**
  String get dataStorageLocalWarning;

  /// Label for dataStorageTitle
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get dataStorageTitle;

  /// No description provided for @dataUploadQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Upload cancelled: {resource} currently uses {used} cloud records; this upload adds {incoming}, but the plan limit is {quota}.'**
  String dataUploadQuotaExceeded(String resource, int used, int incoming, int quota);

  /// Label for dataUploadToCloud
  ///
  /// In en, this message translates to:
  /// **'Upload local data to cloud (Admin)'**
  String get dataUploadToCloud;

  /// Move local data to cloud action
  ///
  /// In en, this message translates to:
  /// **'Move local data to cloud'**
  String get dataUploadToCloudAction;

  /// Label for dataUploadToCloudConfirm
  ///
  /// In en, this message translates to:
  /// **'All local data will first be checked against your current plan limits. Local copies are deleted and cloud mode is enabled only after the entire upload is verified. If it exceeds a limit or fails, local mode remains active. Continue?'**
  String get dataUploadToCloudConfirm;

  /// Label for dataUploadToCloudFailed
  ///
  /// In en, this message translates to:
  /// **'The upload was cancelled. All local records remain on this device.'**
  String get dataUploadToCloudFailed;

  /// Label for dataUploadToCloudSuccess
  ///
  /// In en, this message translates to:
  /// **'Local data was uploaded to the cloud.'**
  String get dataUploadToCloudSuccess;

  /// Label for quotaFreePeriodActive
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get quotaFreePeriodActive;

  /// Label for quotaFreePeriodAutomaticHint
  ///
  /// In en, this message translates to:
  /// **'Limits are suspended only between the selected start and end times.'**
  String get quotaFreePeriodAutomaticHint;

  /// Label for quotaFreePeriodClear
  ///
  /// In en, this message translates to:
  /// **'Clear setting'**
  String get quotaFreePeriodClear;

  /// Label for quotaFreePeriodClearConfirm
  ///
  /// In en, this message translates to:
  /// **'Remove the configured no-limit period? Normal plan limits will apply immediately.'**
  String get quotaFreePeriodClearConfirm;

  /// Label for quotaFreePeriodCleared
  ///
  /// In en, this message translates to:
  /// **'No-limit promotion removed.'**
  String get quotaFreePeriodCleared;

  /// Label for quotaFreePeriodDescription
  ///
  /// In en, this message translates to:
  /// **'New cloud records do not count against plan limits during this period. Normal limits resume automatically afterward.'**
  String get quotaFreePeriodDescription;

  /// Label for quotaFreePeriodDisabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get quotaFreePeriodDisabled;

  /// Label for quotaFreePeriodEdit
  ///
  /// In en, this message translates to:
  /// **'Edit period'**
  String get quotaFreePeriodEdit;

  /// Label for quotaFreePeriodEmpty
  ///
  /// In en, this message translates to:
  /// **'No no-limit periods have been configured.'**
  String get quotaFreePeriodEmpty;

  /// Label for quotaFreePeriodEnabled
  ///
  /// In en, this message translates to:
  /// **'Enable this period'**
  String get quotaFreePeriodEnabled;

  /// Label for quotaFreePeriodEnd
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get quotaFreePeriodEnd;

  /// Label for quotaFreePeriodEnded
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get quotaFreePeriodEnded;

  /// Label for quotaFreePeriodInvalidRange
  ///
  /// In en, this message translates to:
  /// **'The end time must be later than the start time.'**
  String get quotaFreePeriodInvalidRange;

  /// Label for quotaFreePeriodName
  ///
  /// In en, this message translates to:
  /// **'Promotion name'**
  String get quotaFreePeriodName;

  /// Label for quotaFreePeriodNew
  ///
  /// In en, this message translates to:
  /// **'Create a period'**
  String get quotaFreePeriodNew;

  /// Label for quotaFreePeriodSaved
  ///
  /// In en, this message translates to:
  /// **'No-limit promotion saved.'**
  String get quotaFreePeriodSaved;

  /// Label for quotaFreePeriodSaveFailed
  ///
  /// In en, this message translates to:
  /// **'Could not save the no-limit promotion.'**
  String get quotaFreePeriodSaveFailed;

  /// Label for quotaFreePeriodScheduled
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get quotaFreePeriodScheduled;

  /// Label for quotaFreePeriodStart
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get quotaFreePeriodStart;

  /// Label for quotaFreePeriodTitle
  ///
  /// In en, this message translates to:
  /// **'No-limit promotion'**
  String get quotaFreePeriodTitle;

  /// Label for quotaFreePeriodUnnamed
  ///
  /// In en, this message translates to:
  /// **'Unnamed promotion'**
  String get quotaFreePeriodUnnamed;

  /// Label for record category allowance
  ///
  /// In en, this message translates to:
  /// **'Allowance'**
  String get recordCategoryAllowance;

  /// Label for subscriptionActualQuotaTitle
  ///
  /// In en, this message translates to:
  /// **'Your current version and usage'**
  String get subscriptionActualQuotaTitle;

  /// Cloud plan with pricing version
  ///
  /// In en, this message translates to:
  /// **'Cloud {version}'**
  String subscriptionCloudVersionName(String version);

  /// Label for subscriptionCommonFeatures
  ///
  /// In en, this message translates to:
  /// **'Included with both plans'**
  String get subscriptionCommonFeatures;

  /// Label for subscriptionCommonFeaturesDetail
  ///
  /// In en, this message translates to:
  /// **'Calendar, accounting, points, recommended events and attractions, and the administrator question bank. Local-device data remains unlimited. Stocks and Business Plan are administrator-only.'**
  String get subscriptionCommonFeaturesDetail;

  /// Current unlimited administrator access
  ///
  /// In en, this message translates to:
  /// **'Current access: Administrator (unlimited)'**
  String get subscriptionCurrentAdmin;

  /// Current cloud Plus plan
  ///
  /// In en, this message translates to:
  /// **'Current: Cloud Plus'**
  String get subscriptionCurrentCloudPlus;

  /// Label for subscriptionCurrentFree
  ///
  /// In en, this message translates to:
  /// **'Current plan: Cloud Free'**
  String get subscriptionCurrentFree;

  /// Current local Plus plan
  ///
  /// In en, this message translates to:
  /// **'Current: Local Plus'**
  String get subscriptionCurrentLocalPlus;

  /// Label for subscriptionCurrentPlus
  ///
  /// In en, this message translates to:
  /// **'Current plan: Plus'**
  String get subscriptionCurrentPlus;

  /// Label for subscriptionDeleteRecordHint
  ///
  /// In en, this message translates to:
  /// **'Deleting this record will also recalculate today and total values.'**
  String get subscriptionDeleteRecordHint;

  /// No description provided for @subscriptionDowngradeWarning.
  ///
  /// In en, this message translates to:
  /// **'Your cloud data exceeds the free allowance. Remove or move the excess by {date}.'**
  String subscriptionDowngradeWarning(String date);

  /// Label for subscriptionEffectiveDate
  ///
  /// In en, this message translates to:
  /// **'Effective date'**
  String get subscriptionEffectiveDate;

  /// Label for subscriptionFreeName
  ///
  /// In en, this message translates to:
  /// **'Cloud Free'**
  String get subscriptionFreeName;

  /// Label for subscriptionFreePersonalRecords
  ///
  /// In en, this message translates to:
  /// **'Cloud storage: up to 30 records each for calendar, accounting, points, and memories'**
  String get subscriptionFreePersonalRecords;

  /// Label for subscriptionFreePrice
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get subscriptionFreePrice;

  /// Label for subscriptionImagePlusOnly
  ///
  /// In en, this message translates to:
  /// **'Photo uploads are available with Plus.'**
  String get subscriptionImagePlusOnly;

  /// Label for subscriptionImageStorage
  ///
  /// In en, this message translates to:
  /// **'Photo storage'**
  String get subscriptionImageStorage;

  /// Label for subscriptionInactiveAccountWarning
  ///
  /// In en, this message translates to:
  /// **'Free accounts have no expiry date. If no data is added or changed for 3 months, the account and its cloud data will be automatically removed.'**
  String get subscriptionInactiveAccountWarning;

  /// Latest local pricing version
  ///
  /// In en, this message translates to:
  /// **'Local Plus version for the next payment'**
  String get subscriptionLatestLocalVersionTitle;

  /// Local answer history retention
  ///
  /// In en, this message translates to:
  /// **'Unlimited local answer history'**
  String get subscriptionLocalAnswerHistory;

  /// Label for subscriptionLocalPaidFeature
  ///
  /// In en, this message translates to:
  /// **'Unlimited records and photos on this device; data does not automatically appear on other devices'**
  String get subscriptionLocalPaidFeature;

  /// Label for subscriptionLocalPaidName
  ///
  /// In en, this message translates to:
  /// **'Device Plus'**
  String get subscriptionLocalPaidName;

  /// Label for subscriptionLocalPaidPrice
  ///
  /// In en, this message translates to:
  /// **'NT\$129 / quarter'**
  String get subscriptionLocalPaidPrice;

  /// No description provided for @subscriptionLocalUsage.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device: {used} / Unlimited'**
  String subscriptionLocalUsage(int used);

  /// Local plan with pricing version
  ///
  /// In en, this message translates to:
  /// **'Device {version}'**
  String subscriptionLocalVersionName(String version);

  /// Cloud pricing version for next payment
  ///
  /// In en, this message translates to:
  /// **'Next payment: Cloud {version}'**
  String subscriptionNextCloudVersionName(String version);

  /// Latest cloud pricing version
  ///
  /// In en, this message translates to:
  /// **'Cloud version for the next payment'**
  String get subscriptionNextCloudVersionTitle;

  /// Local pricing version for next payment
  ///
  /// In en, this message translates to:
  /// **'Next payment: Device {version}'**
  String subscriptionNextLocalVersionName(String version);

  /// Label for subscriptionNextVersionTitle
  ///
  /// In en, this message translates to:
  /// **'Latest version for your next payment'**
  String get subscriptionNextVersionTitle;

  /// No description provided for @subscriptionOverageItem.
  ///
  /// In en, this message translates to:
  /// **'{resource}: {used}/{quota} (over by {excess})'**
  String subscriptionOverageItem(String resource, int used, int quota, int excess);

  /// Label for subscriptionPlansTitle
  ///
  /// In en, this message translates to:
  /// **'Plans and subscription'**
  String get subscriptionPlansTitle;

  /// Label for subscriptionPlusName
  ///
  /// In en, this message translates to:
  /// **'Cloud Plus'**
  String get subscriptionPlusName;

  /// Label for subscriptionPlusPersonalRecords
  ///
  /// In en, this message translates to:
  /// **'300 cloud records each for calendar, accounting, points, and memories'**
  String get subscriptionPlusPersonalRecords;

  /// Label for subscriptionPlusPrice
  ///
  /// In en, this message translates to:
  /// **'From NT\$129 / quarter'**
  String get subscriptionPlusPrice;

  /// Label for subscriptionPricingVersion
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get subscriptionPricingVersion;

  /// Label for subscriptionPurchaseComingSoon
  ///
  /// In en, this message translates to:
  /// **'In-app subscription coming soon'**
  String get subscriptionPurchaseComingSoon;

  /// Label for subscriptionPurchaseExplanation
  ///
  /// In en, this message translates to:
  /// **'Plus cannot be purchased yet. Once store billing is available, this page will show the official price, renewal terms, purchase, restore, and subscription management actions.'**
  String get subscriptionPurchaseExplanation;

  /// Label for subscriptionQuarterlyPayment
  ///
  /// In en, this message translates to:
  /// **'Quarterly payment'**
  String get subscriptionQuarterlyPayment;

  /// Label for subscriptionQuotaMultiplier
  ///
  /// In en, this message translates to:
  /// **'Quota multiplier'**
  String get subscriptionQuotaMultiplier;

  /// Label for subscriptionQuotaReached
  ///
  /// In en, this message translates to:
  /// **'This plan has reached its limit. Delete older data before adding more, or upgrade to Plus.'**
  String get subscriptionQuotaReached;

  /// No description provided for @subscriptionQuotaReachedDetail.
  ///
  /// In en, this message translates to:
  /// **'Cloud limit reached: {used} of {quota} records are in use, so {remaining} more can be added. Delete an older record, switch to this device, or upgrade to Plus.'**
  String subscriptionQuotaReachedDetail(int used, int quota, int remaining);

  /// Label for subscriptionRenewalRequired
  ///
  /// In en, this message translates to:
  /// **'Your paid period has ended. Cloud data is read-only until you renew or move all cloud data to this device.'**
  String get subscriptionRenewalRequired;

  /// No description provided for @subscriptionUsage.
  ///
  /// In en, this message translates to:
  /// **'Used {used} / {quota}'**
  String subscriptionUsage(int used, int quota);

  /// No description provided for @subscriptionValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {date}'**
  String subscriptionValidUntil(String date);

  /// No description provided for @subscriptionVersionOffer.
  ///
  /// In en, this message translates to:
  /// **'{version} · Effective {date} · NT\${price} per quarter'**
  String subscriptionVersionOffer(String version, String date, int price);

  /// Label for vendor content quota reached
  ///
  /// In en, this message translates to:
  /// **'The active-listing allowance is full. Remove an active listing or upgrade the organizer plan.'**
  String get vendorContentQuotaReached;

  /// Label for vendor image quota reached
  ///
  /// In en, this message translates to:
  /// **'The organizer image allowance is full. Remove images or upgrade the organizer plan.'**
  String get vendorImageQuotaReached;

  /// No description provided for @vendorPlanActivityQuota.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} active activities'**
  String vendorPlanActivityQuota(int count);

  /// No description provided for @vendorPlanAttractionQuota.
  ///
  /// In en, this message translates to:
  /// **'Up to {count} active attractions'**
  String vendorPlanAttractionQuota(int count);

  /// No description provided for @vendorPlanImageQuota.
  ///
  /// In en, this message translates to:
  /// **'{count} MB image storage'**
  String vendorPlanImageQuota(int count);

  /// Label for vendor pricing active only note
  ///
  /// In en, this message translates to:
  /// **'Listing allowances count content that has not ended. Expired content does not occupy an active-listing allowance.'**
  String get vendorPricingActiveOnlyNote;

  /// Label for vendor pricing description
  ///
  /// In en, this message translates to:
  /// **'Start free, then expand the number of public listings and the reporting period as your organization grows.'**
  String get vendorPricingDescription;

  /// Label for vendor pricing title
  ///
  /// In en, this message translates to:
  /// **'Organizer plans'**
  String get vendorPricingTitle;

  /// Label for vendor quota full hint
  ///
  /// In en, this message translates to:
  /// **'An allowance is full. Upgrade or remove an active listing before adding more.'**
  String get vendorQuotaFullHint;

  /// Label for vendor quota near full hint
  ///
  /// In en, this message translates to:
  /// **'An allowance is almost full. Review the available plans before your next submission.'**
  String get vendorQuotaNearFullHint;

  /// No description provided for @vendorQuotaRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count}{suffix} remaining'**
  String vendorQuotaRemaining(int count, String suffix);

  /// Label for weatherClouds
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherClouds;

  /// Label for addToSchedule
  ///
  /// In en, this message translates to:
  /// **'Add to schedule'**
  String get addToSchedule;

  /// Label for calendarCancelAllShares
  ///
  /// In en, this message translates to:
  /// **'Stop sharing all events'**
  String get calendarCancelAllShares;

  /// Label for calendarCancelSingleShare
  ///
  /// In en, this message translates to:
  /// **'Stop sharing this event'**
  String get calendarCancelSingleShare;

  /// Label for calendarInvitationAccept
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get calendarInvitationAccept;

  /// Label for calendarInvitationAccepted
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get calendarInvitationAccepted;

  /// Calendar invitation account error
  ///
  /// In en, this message translates to:
  /// **'That account could not be found.'**
  String get calendarInvitationAccountNotFound;

  /// Label for calendarInvitationDecline
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get calendarInvitationDecline;

  /// Label for calendarInvitationDeclined
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get calendarInvitationDeclined;

  /// Duplicate calendar invitation error
  ///
  /// In en, this message translates to:
  /// **'These events are already shared with this account.'**
  String get calendarInvitationDuplicate;

  /// Selected sharing event is unavailable
  ///
  /// In en, this message translates to:
  /// **'The selected event no longer exists or cannot be shared. Refresh and select it again.'**
  String get calendarInvitationEventUnavailable;

  /// Label for calendarInvitationFailed
  ///
  /// In en, this message translates to:
  /// **'Calendar invitation could not be updated.'**
  String get calendarInvitationFailed;

  /// Calendar invitation error with reason
  ///
  /// In en, this message translates to:
  /// **'Calendar invitation could not be updated: {reason}'**
  String calendarInvitationFailedWithReason(String reason);

  /// Label for calendarInvitationPending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get calendarInvitationPending;

  /// Label for calendarInvitationRevoke
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get calendarInvitationRevoke;

  /// Label for calendarInvitationRevoked
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get calendarInvitationRevoked;

  /// Cannot invite yourself to a calendar
  ///
  /// In en, this message translates to:
  /// **'You cannot invite your own account.'**
  String get calendarInvitationSelfInvite;

  /// Label for calendarInvitationSent
  ///
  /// In en, this message translates to:
  /// **'Invitation sent.'**
  String get calendarInvitationSent;

  /// Invitation state changed
  ///
  /// In en, this message translates to:
  /// **'The invitation status changed. Refresh and try again.'**
  String get calendarInvitationStateChanged;

  /// Label for calendarInvite
  ///
  /// In en, this message translates to:
  /// **'Invite viewers'**
  String get calendarInvite;

  /// Label for calendarInviteHint
  ///
  /// In en, this message translates to:
  /// **'Enter account emails, separated by commas or new lines'**
  String get calendarInviteHint;

  /// Label for calendarNoShareableEvents
  ///
  /// In en, this message translates to:
  /// **'There are no events available to share.'**
  String get calendarNoShareableEvents;

  /// Label for calendarNoSharedEvents
  ///
  /// In en, this message translates to:
  /// **'No events are currently shared.'**
  String get calendarNoSharedEvents;

  /// Label for calendarReceivedInvitations
  ///
  /// In en, this message translates to:
  /// **'Received invitations'**
  String get calendarReceivedInvitations;

  /// Search label for calendar invitation accounts
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get calendarSearchEmail;

  /// Search label for calendar shareable events
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get calendarSearchEvent;

  /// Validation shown when no calendar event is selected for sharing
  ///
  /// In en, this message translates to:
  /// **'Select at least one event to share.'**
  String get calendarSelectEventRequired;

  /// Label for calendarSentInvitations
  ///
  /// In en, this message translates to:
  /// **'Sent invitations'**
  String get calendarSentInvitations;

  /// Label for calendarShareAllEvents
  ///
  /// In en, this message translates to:
  /// **'Share all events'**
  String get calendarShareAllEvents;

  /// No description provided for @calendarSharedBy.
  ///
  /// In en, this message translates to:
  /// **'Shared by {account}'**
  String calendarSharedBy(String account);

  /// Label for calendarSharedReadOnly
  ///
  /// In en, this message translates to:
  /// **'Shared calendar · Read only'**
  String get calendarSharedReadOnly;

  /// Label for calendarShareEvents
  ///
  /// In en, this message translates to:
  /// **'Choose events to share'**
  String get calendarShareEvents;

  /// Label for calendarSharing
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing'**
  String get calendarSharing;

  /// Confirmation shown after calendar sharing changes
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing updated.'**
  String get calendarSharingUpdated;

  /// Label for calendarStopReceiving
  ///
  /// In en, this message translates to:
  /// **'Stop viewing'**
  String get calendarStopReceiving;

  /// Label for eventReminder
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get eventReminder;

  /// Label for eventReminderDesc
  ///
  /// In en, this message translates to:
  /// **'Remind you of upcoming events'**
  String get eventReminderDesc;

  /// Label for eventReminderToday
  ///
  /// In en, this message translates to:
  /// **'Today event reminder'**
  String get eventReminderToday;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pagCalendar'**
  String get pagCalendar;

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

  /// Label for reminderOptionsDefaultDayBefore8am
  ///
  /// In en, this message translates to:
  /// **'1 day before 8 am'**
  String get reminderOptionsDefaultDayBefore8am;

  /// Label for reminderOptionsDefaultSameDay8am
  ///
  /// In en, this message translates to:
  /// **'Sam day 8 am'**
  String get reminderOptionsDefaultSameDay8am;

  /// Label for reminderOptionsOneHourBefore
  ///
  /// In en, this message translates to:
  /// **'1 hour before'**
  String get reminderOptionsOneHourBefore;

  /// Label for reminderOptionsOneMonthBefore
  ///
  /// In en, this message translates to:
  /// **'1 month before'**
  String get reminderOptionsOneMonthBefore;

  /// Label for reminderOptionsOneWeekBefore
  ///
  /// In en, this message translates to:
  /// **'1 week before'**
  String get reminderOptionsOneWeekBefore;

  /// Label for reminderOptionsTwoDaysBefore
  ///
  /// In en, this message translates to:
  /// **'2 days before'**
  String get reminderOptionsTwoDaysBefore;

  /// Label for reminderOptionsTwoWeeksBefore
  ///
  /// In en, this message translates to:
  /// **'2 weeks before'**
  String get reminderOptionsTwoWeeksBefore;

  /// Label for scheduleAlreadyStarted
  ///
  /// In en, this message translates to:
  /// **'Schedule already started'**
  String get scheduleAlreadyStarted;

  /// Label for an ended but unfinished next schedule
  ///
  /// In en, this message translates to:
  /// **'Schedule awaiting review'**
  String get scheduleAwaitingReview;

  /// Warning before saving an overlapping calendar event
  ///
  /// In en, this message translates to:
  /// **'This time overlaps with {count} unfinished schedule items:\n{details}\nSave anyway?'**
  String scheduleConflictBeforeSave(int count, String details);

  /// Label for scheduleConflictCount
  ///
  /// In en, this message translates to:
  /// **'{count} schedule time conflicts today and tomorrow'**
  String scheduleConflictCount(int count);

  /// Today schedule conflict count
  ///
  /// In en, this message translates to:
  /// **'Today has {count} schedule time conflicts'**
  String scheduleConflictToday(int count);

  /// Tomorrow schedule conflict count
  ///
  /// In en, this message translates to:
  /// **'Tomorrow has {count} schedule time conflicts'**
  String scheduleConflictTomorrow(int count);

  /// Confirmation shown before adding a duplicate calendar item
  ///
  /// In en, this message translates to:
  /// **'This item is already in your calendar. Add it again?'**
  String get scheduleDuplicateConfirmation;

  /// Reminder for an ended but unfinished schedule
  ///
  /// In en, this message translates to:
  /// **'This schedule has ended. Check whether it is complete.'**
  String get scheduleNeedsReview;

  /// Count of ended but unfinished schedules
  ///
  /// In en, this message translates to:
  /// **'{count} schedules need review'**
  String scheduleNeedsReviewCount(int count);

  /// Label for scheduleStartsInHours
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} hr'**
  String scheduleStartsInHours(int count);

  /// Label for scheduleStartsInMinutes
  ///
  /// In en, this message translates to:
  /// **'Starts in {count} min'**
  String scheduleStartsInMinutes(int count);

  /// Label for todaySchedule
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todaySchedule;

  /// Tomorrow schedule count shown on the home overview
  ///
  /// In en, this message translates to:
  /// **'Tomorrow: {count} schedules'**
  String tomorrowScheduleCount(int count);

  /// Label for upcomingSchedule
  ///
  /// In en, this message translates to:
  /// **'Upcoming Schedule'**
  String get upcomingSchedule;

  /// Open the calendar to view schedules hidden from the home preview
  ///
  /// In en, this message translates to:
  /// **'View {count} more schedules'**
  String viewRemainingSchedules(int count);

  /// Title for adding or editing an attraction
  ///
  /// In en, this message translates to:
  /// **'Add/Edit attraction'**
  String get attractionAddEdit;

  /// Label for completeEventMessage
  ///
  /// In en, this message translates to:
  /// **'Once completed, this trip will disappear from today\'s list.'**
  String get completeEventMessage;

  /// Label for completeEventTitle
  ///
  /// In en, this message translates to:
  /// **'Complete the schedule'**
  String get completeEventTitle;

  /// Label for add event
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get eventAdd;

  /// Label for add event
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get eventAdd1;

  /// Label for eventAddEdit
  ///
  /// In en, this message translates to:
  /// **'Add/Edit'**
  String get eventAddEdit;

  /// Label for eventAddError
  ///
  /// In en, this message translates to:
  /// **'Add it repeatedly'**
  String get eventAddError;

  /// Label for add event ok
  ///
  /// In en, this message translates to:
  /// **'✅ Event added'**
  String get eventAddOk;

  /// Label for eventAddSub
  ///
  /// In en, this message translates to:
  /// **'Add detailed activities'**
  String get eventAddSub;

  /// Shown when saving a duplicate event
  ///
  /// In en, this message translates to:
  /// **'This event already exists'**
  String get eventAlreadyExists;

  /// Success message shown after completing a schedule
  ///
  /// In en, this message translates to:
  /// **'Schedule completed'**
  String get eventCompleted;

  /// Summary shown after completing a schedule and saving related records
  ///
  /// In en, this message translates to:
  /// **'Schedule completed: {items}'**
  String eventCompletedWithRecords(String items);

  /// Label for eventDelete
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get eventDelete;

  /// Expense direction for an event accounting record
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get eventExpense;

  /// Income direction for an event accounting record
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get eventIncome;

  /// Recommended event refresh button
  ///
  /// In en, this message translates to:
  /// **'Update recommended events'**
  String get eventRefresh;

  /// Recommended event refresh failure message
  ///
  /// In en, this message translates to:
  /// **'Could not update recommended events. Try again later.'**
  String get eventRefreshFailed;

  /// Recommended event refresh already running message
  ///
  /// In en, this message translates to:
  /// **'Recommended events are being updated. Please check again later.'**
  String get eventRefreshRunning;

  /// Recommended event refresh success message
  ///
  /// In en, this message translates to:
  /// **'Recommended events updated.'**
  String get eventRefreshSucceeded;

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

  /// Shown when an event cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not save the event. Please try again later'**
  String get eventSaveFailed;

  /// Label for eventSessionCount
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String eventSessionCount(int count);

  /// Label for Detailed activities
  ///
  /// In en, this message translates to:
  /// **'Detailed activities'**
  String get eventSub;

  /// Label for findRecommendedEvent
  ///
  /// In en, this message translates to:
  /// **'Find an event'**
  String get findRecommendedEvent;

  /// Label for findRecommendedPlace
  ///
  /// In en, this message translates to:
  /// **'Find a place'**
  String get findRecommendedPlace;

  /// Label for multiDayEvent
  ///
  /// In en, this message translates to:
  /// **'{count} consecutive days'**
  String multiDayEvent(int count);

  /// Label for noEventsToUpload
  ///
  /// In en, this message translates to:
  /// **'❌ No events to upload'**
  String get noEventsToUpload;

  /// ==========================================================================
  ///
  /// In en, this message translates to:
  /// **'pageRecommendEvent'**
  String get pageRecommendEvent;

  /// Label for personalEvent
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalEvent;

  /// Label for recommendEvent
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get recommendEvent;

  /// Label for recommendEventZero
  ///
  /// In en, this message translates to:
  /// **'No event'**
  String get recommendEventZero;

  /// Label for recommendPlaces
  ///
  /// In en, this message translates to:
  /// **'Attractions'**
  String get recommendPlaces;

  /// Label for recommendPlacesZero
  ///
  /// In en, this message translates to:
  /// **'No recommended places at the moment'**
  String get recommendPlacesZero;

  /// Label for vendor active activities
  ///
  /// In en, this message translates to:
  /// **'Active activities'**
  String get vendorActiveActivities;

  /// Label for vendor active attractions
  ///
  /// In en, this message translates to:
  /// **'Active attractions'**
  String get vendorActiveAttractions;

  /// Vendor active content mix
  ///
  /// In en, this message translates to:
  /// **'{activities} active activities · {attractions} active attractions'**
  String vendorActivityAttractionMix(int activities, int attractions);

  /// Label for vendor activity label
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get vendorActivityLabel;

  /// Label for vendor all activities
  ///
  /// In en, this message translates to:
  /// **'All submissions'**
  String get vendorAllActivities;

  /// Short label for all submissions
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get vendorAllShort;

  /// Label for vendor analytics card clicks
  ///
  /// In en, this message translates to:
  /// **'Content clicks'**
  String get vendorAnalyticsCardClicks;

  /// Label for vendor analytics days
  ///
  /// In en, this message translates to:
  /// **'Analytics days'**
  String get vendorAnalyticsDays;

  /// No description provided for @vendorAnalyticsDescription.
  ///
  /// In en, this message translates to:
  /// **'Interactions with your activities and attractions during the latest {days} days.'**
  String vendorAnalyticsDescription(int days);

  /// Label for vendor analytics dislikes
  ///
  /// In en, this message translates to:
  /// **'Dislikes'**
  String get vendorAnalyticsDislikes;

  /// Label for vendor analytics empty
  ///
  /// In en, this message translates to:
  /// **'Performance data appears after people discover and interact with your public content.'**
  String get vendorAnalyticsEmpty;

  /// Label for vendor analytics likes
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get vendorAnalyticsLikes;

  /// Label for vendor analytics page views
  ///
  /// In en, this message translates to:
  /// **'Page views'**
  String get vendorAnalyticsPageViews;

  /// Label for vendor analytics registration clicks
  ///
  /// In en, this message translates to:
  /// **'Registration clicks'**
  String get vendorAnalyticsRegistrationClicks;

  /// Label for vendor analytics saves
  ///
  /// In en, this message translates to:
  /// **'Saves'**
  String get vendorAnalyticsSaves;

  /// Label for vendor analytics title
  ///
  /// In en, this message translates to:
  /// **'Performance analytics'**
  String get vendorAnalyticsTitle;

  /// Label for vendor attraction label
  ///
  /// In en, this message translates to:
  /// **'Attraction'**
  String get vendorAttractionLabel;

  /// Label for vendor attraction submission guide title
  ///
  /// In en, this message translates to:
  /// **'Help people discover your attraction'**
  String get vendorAttractionSubmissionGuideTitle;

  /// Vendor content click-through rate
  ///
  /// In en, this message translates to:
  /// **'View-to-click'**
  String get vendorClickThroughRate;

  /// Label for vendor content mix title
  ///
  /// In en, this message translates to:
  /// **'Content overview'**
  String get vendorContentMixTitle;

  /// Label for vendor create account action
  ///
  /// In en, this message translates to:
  /// **'Create an account and submit'**
  String get vendorCreateAccountAction;

  /// Label for vendor create account description
  ///
  /// In en, this message translates to:
  /// **'Create an account to submit activities, follow review status and keep your public information up to date.'**
  String get vendorCreateAccountDescription;

  /// Label for vendor create account title
  ///
  /// In en, this message translates to:
  /// **'Organizing an event?'**
  String get vendorCreateAccountTitle;

  /// Label for vendor dashboard load failed
  ///
  /// In en, this message translates to:
  /// **'Organizer information could not be loaded.'**
  String get vendorDashboardLoadFailed;

  /// Label for vendor dashboard subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage submissions, follow review status and keep track of your current allowance.'**
  String get vendorDashboardSubtitle;

  /// Label for vendor dashboard title
  ///
  /// In en, this message translates to:
  /// **'Organizer workspace'**
  String get vendorDashboardTitle;

  /// Label for vendor manage activities
  ///
  /// In en, this message translates to:
  /// **'Manage activities'**
  String get vendorManageActivities;

  /// Label for vendor manage attractions
  ///
  /// In en, this message translates to:
  /// **'Manage attractions'**
  String get vendorManageAttractions;

  /// Short label for the vendor's own submissions
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get vendorMineShort;

  /// Label for vendor my submissions
  ///
  /// In en, this message translates to:
  /// **'My submissions'**
  String get vendorMySubmissions;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'Strengthen the opening description, highlights and image so planners know why to open it.'**
  String get vendorNextStepClickMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Turn views into interest'**
  String get vendorNextStepClickTitle;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'A clear title, cover image and city help people discover and understand your listing.'**
  String get vendorNextStepExposureMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Make the first impression count'**
  String get vendorNextStepExposureTitle;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'Start with one complete activity: add an accurate date, place, image and registration link.'**
  String get vendorNextStepFirstMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Publish your first listing'**
  String get vendorNextStepFirstTitle;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'Keep dates and availability current, then use the conversion rates to improve the next listing.'**
  String get vendorNextStepGrowingMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Your content is creating action'**
  String get vendorNextStepGrowingTitle;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'Check that the registration URL and call to action are clear and still available.'**
  String get vendorNextStepRegistrationMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Make registration easier'**
  String get vendorNextStepRegistrationTitle;

  /// Vendor next action message
  ///
  /// In en, this message translates to:
  /// **'You can track the result here. Once approved, everyone can discover it while planning.'**
  String get vendorNextStepReviewMessage;

  /// Vendor next action title
  ///
  /// In en, this message translates to:
  /// **'Your submission is being reviewed'**
  String get vendorNextStepReviewTitle;

  /// No description provided for @vendorPendingReviewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} submissions awaiting review'**
  String vendorPendingReviewCount(int count);

  /// Vendor pending review guidance
  ///
  /// In en, this message translates to:
  /// **'Review status is kept here. Published listings become visible to everyone.'**
  String get vendorPendingReviewHint;

  /// No description provided for @vendorPositiveActions.
  ///
  /// In en, this message translates to:
  /// **'{count} saves and likes'**
  String vendorPositiveActions(int count);

  /// Vendor review status mix
  ///
  /// In en, this message translates to:
  /// **'{published} public · {pending} awaiting review'**
  String vendorPublishedPendingMix(int published, int pending);

  /// Label for vendor quality city
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get vendorQualityCity;

  /// Label for vendor quality date
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get vendorQualityDate;

  /// Label for vendor quality description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get vendorQualityDescription;

  /// Label for vendor quality link
  ///
  /// In en, this message translates to:
  /// **'Registration link'**
  String get vendorQualityLink;

  /// Label for vendor quality location
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get vendorQualityLocation;

  /// Label for vendor quality name
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get vendorQualityName;

  /// Vendor submission quality progress
  ///
  /// In en, this message translates to:
  /// **'Submission completeness: {count} of {total}'**
  String vendorQualityProgress(int count, int total);

  /// No description provided for @vendorQuarterlyPrice.
  ///
  /// In en, this message translates to:
  /// **'NT\${price} / quarter'**
  String vendorQuarterlyPrice(int price);

  /// Label for vendor recent submissions empty
  ///
  /// In en, this message translates to:
  /// **'No submissions yet. Add your first activity or attraction.'**
  String get vendorRecentSubmissionsEmpty;

  /// Label for vendor recent submissions title
  ///
  /// In en, this message translates to:
  /// **'Recent submissions'**
  String get vendorRecentSubmissionsTitle;

  /// Label for vendor registration analytics
  ///
  /// In en, this message translates to:
  /// **'See content performance in one workspace'**
  String get vendorRegistrationAnalytics;

  /// Label for vendor registration description
  ///
  /// In en, this message translates to:
  /// **'This account opens an organizer workspace for managing activities, attractions and review status.'**
  String get vendorRegistrationDescription;

  /// Label for vendor registration free start
  ///
  /// In en, this message translates to:
  /// **'Start with the free organizer plan'**
  String get vendorRegistrationFreeStart;

  /// Vendor registration click conversion rate
  ///
  /// In en, this message translates to:
  /// **'Click-to-registration'**
  String get vendorRegistrationRate;

  /// Label for vendor registration title
  ///
  /// In en, this message translates to:
  /// **'Organizer account'**
  String get vendorRegistrationTitle;

  /// Label for vendor submission benefit manage
  ///
  /// In en, this message translates to:
  /// **'Manage your own information'**
  String get vendorSubmissionBenefitManage;

  /// Label for vendor submission benefit reach
  ///
  /// In en, this message translates to:
  /// **'Reach active planners'**
  String get vendorSubmissionBenefitReach;

  /// Label for vendor submission benefit review
  ///
  /// In en, this message translates to:
  /// **'Clear review status'**
  String get vendorSubmissionBenefitReview;

  /// Label for vendor submission description
  ///
  /// In en, this message translates to:
  /// **'Publish activities and attractions where people plan their time. Keep ownership and update your listing after review.'**
  String get vendorSubmissionDescription;

  /// Label for vendor submission guide description
  ///
  /// In en, this message translates to:
  /// **'Add an accurate date, place, organizer and registration link. Your submission becomes public after review; later edits return it for review.'**
  String get vendorSubmissionGuideDescription;

  /// Label for vendor submission guide title
  ///
  /// In en, this message translates to:
  /// **'Help people discover your activity'**
  String get vendorSubmissionGuideTitle;

  /// Label for vendor submission center
  ///
  /// In en, this message translates to:
  /// **'Submission center'**
  String get vendorSubmissionTitle;

  /// Label for vendor submit activity
  ///
  /// In en, this message translates to:
  /// **'Submit activity'**
  String get vendorSubmitActivity;

  /// Label for vendor submit attraction
  ///
  /// In en, this message translates to:
  /// **'Submit attraction'**
  String get vendorSubmitAttraction;

  /// Short label for submitting vendor content
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get vendorSubmitShort;

  /// Label for vendor untitled submission
  ///
  /// In en, this message translates to:
  /// **'Untitled submission'**
  String get vendorUntitledSubmission;

  /// Open the recommendation page to view hidden results
  ///
  /// In en, this message translates to:
  /// **'View {count} more recommendations'**
  String viewRemainingRecommendations(int count);

  /// Label for weekendEvent
  ///
  /// In en, this message translates to:
  /// **'Weekend event'**
  String get weekendEvent;

  /// Label for city
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Label for country
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Label for countryAustralia
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get countryAustralia;

  /// Label for countryCanada
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get countryCanada;

  /// Label for countryChina
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get countryChina;

  /// Label for countryFrance
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get countryFrance;

  /// Label for countryGermany
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get countryGermany;

  /// Label for countryHongKong
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get countryHongKong;

  /// Label for countryIndia
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get countryIndia;

  /// Label for countryIndonesia
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get countryIndonesia;

  /// Label for countryItaly
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get countryItaly;

  /// Label for countryJapan
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get countryJapan;

  /// Label for countryMacau
  ///
  /// In en, this message translates to:
  /// **'Macau'**
  String get countryMacau;

  /// Label for countryMalaysia
  ///
  /// In en, this message translates to:
  /// **'Malaysia'**
  String get countryMalaysia;

  /// Label for countryNetherlands
  ///
  /// In en, this message translates to:
  /// **'Netherlands'**
  String get countryNetherlands;

  /// Label for countryNewZealand
  ///
  /// In en, this message translates to:
  /// **'New Zealand'**
  String get countryNewZealand;

  /// Label for countryPhilippines
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get countryPhilippines;

  /// Label for countrySingapore
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get countrySingapore;

  /// Label for countrySouthKorea
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get countrySouthKorea;

  /// Label for countrySpain
  ///
  /// In en, this message translates to:
  /// **'Spain'**
  String get countrySpain;

  /// Label for countrySwitzerland
  ///
  /// In en, this message translates to:
  /// **'Switzerland'**
  String get countrySwitzerland;

  /// Label for countryTaiwan
  ///
  /// In en, this message translates to:
  /// **'Taiwan'**
  String get countryTaiwan;

  /// Label for countryThailand
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get countryThailand;

  /// Label for countryUnitedArabEmirates
  ///
  /// In en, this message translates to:
  /// **'United Arab Emirates'**
  String get countryUnitedArabEmirates;

  /// Label for countryUnitedKingdom
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get countryUnitedKingdom;

  /// Label for countryUnitedStates
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get countryUnitedStates;

  /// Label for countryVietnam
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get countryVietnam;

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

  /// Label for location
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// Label for mapCoordinateBackfill
  ///
  /// In en, this message translates to:
  /// **'Fill map coordinates'**
  String get mapCoordinateBackfill;

  /// Label for mapCoordinateBackfillFailed
  ///
  /// In en, this message translates to:
  /// **'Could not fill map coordinates. Try again later.'**
  String get mapCoordinateBackfillFailed;

  /// No description provided for @mapCoordinateBackfillResult.
  ///
  /// In en, this message translates to:
  /// **'Saved {saved}; {remaining} remaining; coverage {coverage}%.'**
  String mapCoordinateBackfillResult(int saved, int remaining, String coverage);

  /// Label for openMap
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get openMap;

  /// Label for selectCity
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get selectCity;

  /// Label for switchToMap
  ///
  /// In en, this message translates to:
  /// **'Switch to map'**
  String get switchToMap;

  /// Label for weatherClear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// Label for weatherDrizzle
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

  /// Weather forecast dialog title
  ///
  /// In en, this message translates to:
  /// **'Weather forecast'**
  String get weatherForecast;

  /// Maximum weather temperature label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get weatherMaximum;

  /// Minimum weather temperature label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get weatherMinimum;

  /// Label for weatherMist
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get weatherMist;

  /// Label for weatherRain
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// Label for weatherSnow
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// Weather temperature label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherTemperature;

  /// Label for weatherThunderstorm
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// Memory record in the schedule completion summary
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get eventMemory;

  /// Label for memoryAdd
  ///
  /// In en, this message translates to:
  /// **'Add Memory'**
  String get memoryAdd;

  /// Label for memoryAddError
  ///
  /// In en, this message translates to:
  /// **'Do you want to add the memory again'**
  String get memoryAddError;

  /// Label for memoryAdd ok
  ///
  /// In en, this message translates to:
  /// **'✅ Memory Added'**
  String get memoryAddOk;

  /// Label for memoryCountForDay
  ///
  /// In en, this message translates to:
  /// **'{count} memories'**
  String memoryCountForDay(int count);

  /// Label for memoryCountForMonth
  ///
  /// In en, this message translates to:
  /// **'{count} this month'**
  String memoryCountForMonth(int count);

  /// Summary of loaded memory journey
  ///
  /// In en, this message translates to:
  /// **'{memoryCount} loaded memories across {dayCount} days and {cityCount} cities'**
  String memoryJourneySummary(int memoryCount, int dayCount, int cityCount);

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

  /// Label for accountAlreadyExists
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get accountAlreadyExists;

  /// Label for accountCreate
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get accountCreate;

  /// Label for accountDefault
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get accountDefault;

  /// No description provided for @accountDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String accountDeleteConfirmation(String name);

  /// Label for accountingSpeechHint
  ///
  /// In en, this message translates to:
  /// **'For example: add/subtract an amount'**
  String get accountingSpeechHint;

  /// Label for accountingUnit
  ///
  /// In en, this message translates to:
  /// **''**
  String get accountingUnit;

  /// Shown when there are no accounts to select
  ///
  /// In en, this message translates to:
  /// **'No account has been created yet. Create one before selecting it.'**
  String get accountListEmpty;

  /// Shown when the account selector cannot load accounts
  ///
  /// In en, this message translates to:
  /// **'Could not load the account list. Please try again later'**
  String get accountListLoadFailed;

  /// Label for accountMaster
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get accountMaster;

  /// Label for accountName
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

  /// Label for accountNew
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountNew;

  /// Label for accountPersonal
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get accountPersonal;

  /// Label for accountProject
  ///
  /// In en, this message translates to:
  /// **'Journey'**
  String get accountProject;

  /// Label for accountRecords
  ///
  /// In en, this message translates to:
  /// **'Account Records'**
  String get accountRecords;

  /// Label for accountSetMainCurrency
  ///
  /// In en, this message translates to:
  /// **'Set main currency'**
  String get accountSetMainCurrency;

  /// Label for accountSwitchCurrency
  ///
  /// In en, this message translates to:
  /// **'Switch currency'**
  String get accountSwitchCurrency;

  /// Currency column title
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyLabel;

  /// Label for editRecord
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecord;

  /// Hint for connecting money and points accounts
  ///
  /// In en, this message translates to:
  /// **'Choose money and points accounts to review your day in one step.'**
  String get homeInsightConnectAccounts;

  /// Label for quickAddAccounting
  ///
  /// In en, this message translates to:
  /// **'Quick money entry'**
  String get quickAddAccounting;

  /// Label for record all categories
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get recordAllCategories;

  /// Label for recordCategoryArts
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get recordCategoryArts;

  /// Label for record category bonus
  ///
  /// In en, this message translates to:
  /// **'Bonus'**
  String get recordCategoryBonus;

  /// Label for recordCategoryClothing
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get recordCategoryClothing;

  /// Label for recordCategoryEducation
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get recordCategoryEducation;

  /// Label for recordCategoryEntertainment
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get recordCategoryEntertainment;

  /// Label for recordCategoryFitness
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get recordCategoryFitness;

  /// Label for recordCategoryFood
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get recordCategoryFood;

  /// Label for recordCategoryHousing
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get recordCategoryHousing;

  /// Label for recordCategoryIntelligence
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get recordCategoryIntelligence;

  /// Label for record category investment income
  ///
  /// In en, this message translates to:
  /// **'Investment income'**
  String get recordCategoryInvestmentIncome;

  /// Label for record category other income
  ///
  /// In en, this message translates to:
  /// **'Other income'**
  String get recordCategoryOtherIncome;

  /// Label for record category refund
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get recordCategoryRefund;

  /// Record category always included regardless of date
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get recordCategoryReserved;

  /// Label for record category salary
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get recordCategorySalary;

  /// Label for recordCategoryTransportation
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get recordCategoryTransportation;

  /// Label for recordCategoryUncategorized
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get recordCategoryUncategorized;

  /// Label for recordCategoryVirtue
  ///
  /// In en, this message translates to:
  /// **'Virtue'**
  String get recordCategoryVirtue;

  /// Label for recordDate
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get recordDate;

  /// Label for record net change
  ///
  /// In en, this message translates to:
  /// **'Net change'**
  String get recordNetChange;

  /// Label for recordPleaseConfirm
  ///
  /// In en, this message translates to:
  /// **'Please confirm'**
  String get recordPleaseConfirm;

  /// Label for recordPrimaryCategory
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get recordPrimaryCategory;

  /// Label for record search hint
  ///
  /// In en, this message translates to:
  /// **'Search description or subcategory'**
  String get recordSearchHint;

  /// Label for recordSecondaryCategory
  ///
  /// In en, this message translates to:
  /// **'Custom subcategory (optional)'**
  String get recordSecondaryCategory;

  /// Label for recordSubmit
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get recordSubmit;

  /// Label for the record time
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get recordTime;

  /// Label for recordTotal
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get recordTotal;

  /// Label for recordValue
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get recordValue;

  /// Label for selectAccount
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get selectAccount;

  /// Label for todayIncomeExpense
  ///
  /// In en, this message translates to:
  /// **'Today\'s Income and Expenses'**
  String get todayIncomeExpense;

  /// Deduct points when completing an event
  ///
  /// In en, this message translates to:
  /// **'Deduct points'**
  String get eventPointDecrease;

  /// Increase points when completing an event
  ///
  /// In en, this message translates to:
  /// **'Add points'**
  String get eventPointIncrease;

  /// Label for group point accounts
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get pointGroup;

  /// Label for PointsRecord
  ///
  /// In en, this message translates to:
  /// **'Points Record'**
  String get pointsRecord;

  /// Label for pointsSpeechHint
  ///
  /// In en, this message translates to:
  /// **'For example: add/subtract points'**
  String get pointsSpeechHint;

  /// Label for pointsUnit
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsUnit;

  /// Label for quickAddPoints
  ///
  /// In en, this message translates to:
  /// **'Quick points entry'**
  String get quickAddPoints;

  /// Label for todayPoints
  ///
  /// In en, this message translates to:
  /// **'Today\'s Points'**
  String get todayPoints;

  /// Total points of the selected account
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

  /// Label for activeQuestion
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeQuestion;

  /// Label for addQuestion
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get addQuestion;

  /// Label for adminQuestionBank
  ///
  /// In en, this message translates to:
  /// **'Admin question bank'**
  String get adminQuestionBank;

  /// Label for allQuestionStatuses
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allQuestionStatuses;

  /// Label for completedGrammarQuestion
  ///
  /// In en, this message translates to:
  /// **'Complete question with the answer (for example, We are young)'**
  String get completedGrammarQuestion;

  /// Label for customQuestionGroup
  ///
  /// In en, this message translates to:
  /// **'+ Create a new category'**
  String get customQuestionGroup;

  /// Label for deactivateQuestion
  ///
  /// In en, this message translates to:
  /// **'Deactivate question'**
  String get deactivateQuestion;

  /// Label for duplicateQuestion
  ///
  /// In en, this message translates to:
  /// **'The same question and answer already exist in your selected question group.'**
  String get duplicateQuestion;

  /// Label for editQuestion
  ///
  /// In en, this message translates to:
  /// **'Edit question'**
  String get editQuestion;

  /// Label for Game
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get game;

  /// Label for game failed
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get gameFailed;

  /// Game level label
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get gameLevel;

  /// Empty game progress message
  ///
  /// In en, this message translates to:
  /// **'No game records'**
  String get gameNoRecords;

  /// Label for game passed
  ///
  /// In en, this message translates to:
  /// **'Pass!'**
  String get gamePassed;

  /// Label for gameProgressSummary
  ///
  /// In en, this message translates to:
  /// **'Passed {passed} of {total} levels'**
  String gameProgressSummary(int passed, int total);

  /// Label for gameRecentBestScore
  ///
  /// In en, this message translates to:
  /// **'Recent best {score}'**
  String gameRecentBestScore(String score);

  /// Label for gameRecentPracticeSummary
  ///
  /// In en, this message translates to:
  /// **'{attempts} recent attempts, {passed} passed'**
  String gameRecentPracticeSummary(int attempts, int passed);

  /// Game score label
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get gameScore;

  /// Game score value
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String gameScoreValue(num score);

  /// Game start button label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get gameStart;

  /// No description provided for @gameTitleScore.
  ///
  /// In en, this message translates to:
  /// **'{game} ({score}/100)'**
  String gameTitleScore(String game, num score);

  /// Label for grammarAnswerMustAppear
  ///
  /// In en, this message translates to:
  /// **'The complete question must contain the correct answer so the blank can be created automatically.'**
  String get grammarAnswerMustAppear;

  /// Label for grammarBaseWord
  ///
  /// In en, this message translates to:
  /// **'Base word (for example, head)'**
  String get grammarBaseWord;

  /// Label for grammarQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'For grammar questions, enter a complete sentence such as We are young; are becomes the blank automatically. For the plural category, enter only head and heads.'**
  String get grammarQuestionHelp;

  /// Label for inactiveQuestion
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactiveQuestion;

  /// Label for japaneseTranslationQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter Japanese in Question and its translation in Correct answer. Create at least 3 questions in the same group.'**
  String get japaneseTranslationQuestionHelp;

  /// Label for koreanTranslationQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter Korean in Question and its translation in Correct answer. Create at least 3 questions in the same group.'**
  String get koreanTranslationQuestionHelp;

  /// Label for leaveGameConfirmation
  ///
  /// In en, this message translates to:
  /// **'Leave this game and return to the previous page?'**
  String get leaveGameConfirmation;

  /// Local question bank restriction
  ///
  /// In en, this message translates to:
  /// **'Local mode only uses your question bank on this device. The admin question bank is unavailable.'**
  String get localQuestionBankOnly;

  /// Label for monominoGameTitle
  ///
  /// In en, this message translates to:
  /// **'Monomino Game'**
  String get monominoGameTitle;

  /// Label for myQuestionBank
  ///
  /// In en, this message translates to:
  /// **'My question bank'**
  String get myQuestionBank;

  /// Label for myQuestionBankEmpty
  ///
  /// In en, this message translates to:
  /// **'Your question bank has no questions available for this level. Add a question first.'**
  String get myQuestionBankEmpty;

  /// Label for myQuestions
  ///
  /// In en, this message translates to:
  /// **'My questions'**
  String get myQuestions;

  /// Label for newQuestionGroup
  ///
  /// In en, this message translates to:
  /// **'New category name'**
  String get newQuestionGroup;

  /// Label for noMyQuestions
  ///
  /// In en, this message translates to:
  /// **'You have not added any questions for this game yet.'**
  String get noMyQuestions;

  /// Label for polyominoGameTitle
  ///
  /// In en, this message translates to:
  /// **'Polyomino Game'**
  String get polyominoGameTitle;

  /// Label for puzzleMapTitle
  ///
  /// In en, this message translates to:
  /// **'Puzzle Map'**
  String get puzzleMapTitle;

  /// Label for question
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// Label for questionAdded
  ///
  /// In en, this message translates to:
  /// **'Question added to your question bank'**
  String get questionAdded;

  /// Label for question bank
  ///
  /// In en, this message translates to:
  /// **'Question bank'**
  String get questionBank;

  /// Shown when the selected shared question bank cannot start the game
  ///
  /// In en, this message translates to:
  /// **'The selected question bank does not have enough questions for this level.'**
  String get questionBankInsufficient;

  /// Label for questionDeactivated
  ///
  /// In en, this message translates to:
  /// **'Question deactivated.'**
  String get questionDeactivated;

  /// Label for questionDeleted
  ///
  /// In en, this message translates to:
  /// **'Question deleted'**
  String get questionDeleted;

  /// Label for questionExample
  ///
  /// In en, this message translates to:
  /// **'Question example'**
  String get questionExample;

  /// Label for questionGroup
  ///
  /// In en, this message translates to:
  /// **'Question group'**
  String get questionGroup;

  /// Label for questionGroupLevelNumber
  ///
  /// In en, this message translates to:
  /// **'Level number after the category (blank means 1)'**
  String get questionGroupLevelNumber;

  /// Label for questionGroupLevelRange
  ///
  /// In en, this message translates to:
  /// **'The level number must be between 1 and 30.'**
  String get questionGroupLevelRange;

  /// Shown when answer history prevents question deletion
  ///
  /// In en, this message translates to:
  /// **'This question has answer history and cannot be deleted. You can deactivate it instead.'**
  String get questionHasAnswersDeleteBlocked;

  /// Label for questionReactivated
  ///
  /// In en, this message translates to:
  /// **'Question reactivated.'**
  String get questionReactivated;

  /// Label for questionStatus
  ///
  /// In en, this message translates to:
  /// **'Question status'**
  String get questionStatus;

  /// Label for questionStatusUpdateFailed
  ///
  /// In en, this message translates to:
  /// **'Question status could not be updated. Please try again.'**
  String get questionStatusUpdateFailed;

  /// Label for questionUpdated
  ///
  /// In en, this message translates to:
  /// **'Question updated'**
  String get questionUpdated;

  /// Label for reactivateQuestion
  ///
  /// In en, this message translates to:
  /// **'Reactivate question'**
  String get reactivateQuestion;

  /// Label for recordCategorySocial
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get recordCategorySocial;

  /// Label for scratchGameTitle
  ///
  /// In en, this message translates to:
  /// **'Scratch Game'**
  String get scratchGameTitle;

  /// Label for scratchMazeTitle
  ///
  /// In en, this message translates to:
  /// **'Scratch Game (Maze)'**
  String get scratchMazeTitle;

  /// Label for sentenceOrWord
  ///
  /// In en, this message translates to:
  /// **'Complete word or correct sentence'**
  String get sentenceOrWord;

  /// Label for sentenceQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter a complete word or correct sentence, such as mother or I love apples. It will be split into rearrangeable parts automatically.'**
  String get sentenceQuestionHelp;

  /// Label for socialTitle
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get socialTitle;

  /// Label for speakingQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the word or sentence the user should read aloud. Example: Nice to meet you.'**
  String get speakingQuestionHelp;

  /// Label for threeQuestionsRequired
  ///
  /// In en, this message translates to:
  /// **'This question bank needs at least 3 available questions for the current level.'**
  String get threeQuestionsRequired;

  /// Label for translationQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the source text and its translation. Create at least 3 questions in the same group so the game can generate two incorrect choices.'**
  String get translationQuestionHelp;

  /// Label for translationTitle
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationTitle;

  /// Label for wordSearchQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter an English word in Question and its meaning in Correct answer. Example: apple / 蘋果.'**
  String get wordSearchQuestionHelp;

  /// Label for wordSentenceBuilderTitle
  ///
  /// In en, this message translates to:
  /// **'Word and Sentence Builder'**
  String get wordSentenceBuilderTitle;

  /// Label for adminUserExistingPlans
  ///
  /// In en, this message translates to:
  /// **'Existing user pricing versions'**
  String get adminUserExistingPlans;

  /// Label for admin vendor existing plans
  ///
  /// In en, this message translates to:
  /// **'Existing pricing versions'**
  String get adminVendorExistingPlans;

  /// Label for attraction business hours
  ///
  /// In en, this message translates to:
  /// **'Business hours'**
  String get businessHours;

  /// Label for BusinessPlan
  ///
  /// In en, this message translates to:
  /// **'Business Plan'**
  String get businessPlan;

  /// Label for dataCleanupLocalExplanation
  ///
  /// In en, this message translates to:
  /// **'Device data is unlimited. You can clear all personal data stored on this device.'**
  String get dataCleanupLocalExplanation;

  /// Label for planTitle
  ///
  /// In en, this message translates to:
  /// **'Plan title'**
  String get planTitle;

  /// Label for selectTemplate
  ///
  /// In en, this message translates to:
  /// **'Select template'**
  String get selectTemplate;

  /// Label for untitledPlan
  ///
  /// In en, this message translates to:
  /// **'Untitled plan'**
  String get untitledPlan;

  /// No description provided for @vendorCurrentPlan.
  ///
  /// In en, this message translates to:
  /// **'Current plan: {plan}'**
  String vendorCurrentPlan(String plan);

  /// No description provided for @vendorPlanAnalyticsDays.
  ///
  /// In en, this message translates to:
  /// **'Analytics for the latest {count} days'**
  String vendorPlanAnalyticsDays(int count);

  /// Label for vendor custom plan
  ///
  /// In en, this message translates to:
  /// **'Custom plan'**
  String get vendorPlanCustomName;

  /// Label for vendor free plan
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get vendorPlanFreeName;

  /// Label for vendor growth plan
  ///
  /// In en, this message translates to:
  /// **'Growth plan'**
  String get vendorPlanGrowthName;

  /// Label for vendor partner plan
  ///
  /// In en, this message translates to:
  /// **'Partner plan'**
  String get vendorPlanPartnerName;

  /// Label for vendor view plans
  ///
  /// In en, this message translates to:
  /// **'View plans'**
  String get vendorViewPlans;

  /// Label for stock
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

  /// No description provided for @stockClosingPrice.
  ///
  /// In en, this message translates to:
  /// **'Closing price: {value}'**
  String stockClosingPrice(String value);

  /// Stock page dashboard title
  ///
  /// In en, this message translates to:
  /// **'📊 Market dashboard'**
  String get stockDashboardTitle;

  /// Stock page foreign buy ranking title
  ///
  /// In en, this message translates to:
  /// **'Net foreign buy ranking'**
  String get stockForeignBuy;

  /// Stock page foreign sell ranking title
  ///
  /// In en, this message translates to:
  /// **'Net foreign sell ranking'**
  String get stockForeignSell;

  /// Stock page initial load failure
  ///
  /// In en, this message translates to:
  /// **'Stock data could not be loaded. Please try again.'**
  String get stockLoadFailed;

  /// Label for stockNet
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get stockNet;

  /// Stock page empty state
  ///
  /// In en, this message translates to:
  /// **'No stock data is currently available.'**
  String get stockNoData;

  /// Load the latest stock data button
  ///
  /// In en, this message translates to:
  /// **'Load latest data'**
  String get stockRetry;

  /// Label for stockSelectDate
  ///
  /// In en, this message translates to:
  /// **'Stock date'**
  String get stockSelectDate;

  /// Stock page thousand lots unit
  ///
  /// In en, this message translates to:
  /// **' thousand lots'**
  String get stockThousandLots;

  /// No description provided for @stockTradingVolume.
  ///
  /// In en, this message translates to:
  /// **'Trading volume: {value} lots'**
  String stockTradingVolume(String value);

  /// Stock page background update failure status
  ///
  /// In en, this message translates to:
  /// **'The stock update failed. The last available data is still displayed.'**
  String get stockUpdateFailed;

  /// Stock page background update status
  ///
  /// In en, this message translates to:
  /// **'Stock data and model are updating. New results will appear automatically.'**
  String get stockUpdateInProgress;

  /// Stock page background update success status
  ///
  /// In en, this message translates to:
  /// **'Stock data and model update completed.'**
  String get stockUpdateSucceeded;

  /// Label for Feedback
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Label for feedbackContent
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get feedbackContent;

  /// No description provided for @feedbackProcessedBy.
  ///
  /// In en, this message translates to:
  /// **'Processed by {name} at {time}'**
  String feedbackProcessedBy(String name, String time);

  /// Label for feedbackPurpose
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get feedbackPurpose;

  /// Label for feedbackRequired
  ///
  /// In en, this message translates to:
  /// **'Purpose and content are required.'**
  String get feedbackRequired;

  /// No description provided for @feedbackSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send feedback: {error}'**
  String feedbackSendFailed(String error);

  /// Label for feedbackSent
  ///
  /// In en, this message translates to:
  /// **'Feedback sent successfully.'**
  String get feedbackSent;

  /// Label for statusCompleted
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// Label for statusInProgress
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// Label for statusPending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// Registration legal agreement required message
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Privacy Policy and Terms of Service before registering.'**
  String get acceptLegalTermsRequired;

  /// Account deletion cancellation is pending
  ///
  /// In en, this message translates to:
  /// **'Cancellation is waiting for administrator confirmation.'**
  String get accountDeletionCancellationPending;

  /// Account deletion cancellation submitted
  ///
  /// In en, this message translates to:
  /// **'Cancellation requested. Waiting for administrator confirmation.'**
  String get accountDeletionCancellationSubmitted;

  /// Cancel an account deletion request
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get accountDeletionCancelRequest;

  /// Confirmation after self-service account deletion
  ///
  /// In en, this message translates to:
  /// **'Your deletion request was sent to an administrator.'**
  String get accountDeletionCompleted;

  /// Account deletion email fallback message
  ///
  /// In en, this message translates to:
  /// **'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.'**
  String get accountDeletionEmailUnavailable;

  /// Self-service account deletion error
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed: {message}'**
  String accountDeletionFailed(Object message);

  /// Account deletion request is pending
  ///
  /// In en, this message translates to:
  /// **'Request pending'**
  String get accountDeletionPending;

  /// Pending account deletion explanation
  ///
  /// In en, this message translates to:
  /// **'Your account deletion request is waiting for administrator review. You can request cancellation if you no longer want to delete the account.'**
  String get accountDeletionPendingDescription;

  /// Account deletion request explanation
  ///
  /// In en, this message translates to:
  /// **'Your request will be sent to an administrator. The account and related data will be deleted only after approval.'**
  String get accountDeletionRequestDescription;

  /// Short account menu label for account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountMenuAccountDeletion;

  /// Short account menu label for data export
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get accountMenuDataExport;

  /// Administrator confirmed cancellation
  ///
  /// In en, this message translates to:
  /// **'Cancellation confirmed and the original deletion request was removed.'**
  String get adminAccountDeletionCancellationConfirmed;

  /// Cancellation request shown to administrators
  ///
  /// In en, this message translates to:
  /// **'The user requested cancellation of account deletion.'**
  String get adminAccountDeletionCancellationRequested;

  /// Administrator completed account deletion
  ///
  /// In en, this message translates to:
  /// **'The account and its related data were deleted.'**
  String get adminAccountDeletionCompleted;

  /// Administrator confirms cancellation
  ///
  /// In en, this message translates to:
  /// **'Confirm cancellation'**
  String get adminAccountDeletionConfirmCancellation;

  /// Registration legal agreement prefix
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get agreeToLegalTermsPrefix;

  /// Confirmation after data export
  ///
  /// In en, this message translates to:
  /// **'Your data export is ready: {path}'**
  String dataExportCompleted(Object path);

  /// Personal data export email fallback message
  ///
  /// In en, this message translates to:
  /// **'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.'**
  String get dataExportEmailUnavailable;

  /// Data export error
  ///
  /// In en, this message translates to:
  /// **'Data export failed: {message}'**
  String dataExportFailed(Object message);

  /// Pages included in personal data export
  ///
  /// In en, this message translates to:
  /// **'Included pages: calendar, memories, accounting records, and point records.'**
  String get dataExportIncludedPages;

  /// Personal data export request explanation
  ///
  /// In en, this message translates to:
  /// **'An Excel file containing your cloud and local personal data will be downloaded to this device.'**
  String get dataExportRequestDescription;

  /// Personal data export summary sheet name
  ///
  /// In en, this message translates to:
  /// **'Export summary'**
  String get dataExportSummarySheet;

  /// Label for exportExcel
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportExcel;

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

  /// Short status shown beside a legal document link after reading
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get legalDocumentRead;

  /// Confirmation shown when a legal document has been read
  ///
  /// In en, this message translates to:
  /// **'Reading complete'**
  String get legalDocumentReadComplete;

  /// Connector between privacy policy and terms of service
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get legalTermsConnector;

  /// Label for noEventsToExport
  ///
  /// In en, this message translates to:
  /// **'❌ No events to export'**
  String get noEventsToExport;

  /// Label for notSupportExport
  ///
  /// In en, this message translates to:
  /// **'⚠️ Not support export'**
  String get notSupportExport;

  /// Label for privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Message shown when both legal documents have not been read
  ///
  /// In en, this message translates to:
  /// **'Please read both the Privacy Policy and Terms of Service before agreeing.'**
  String get readLegalTermsRequired;

  /// Label for account deletion request
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get requestAccountDeletion;

  /// Label for personal data export request
  ///
  /// In en, this message translates to:
  /// **'Request personal data export'**
  String get requestDataExport;

  /// Label for terms of service
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;
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
