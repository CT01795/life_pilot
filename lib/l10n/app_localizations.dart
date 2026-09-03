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

  /// Password reset email resend countdown
  ///
  /// In en, this message translates to:
  /// **'Retry in {seconds}s'**
  String resetPasswordCooldown(int seconds);

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
  /// **'The system cannot find a valid [verification credential], or the credential has expired.'**
  String get noRecoverySession;

  /// Label for reset password error
  ///
  /// In en, this message translates to:
  /// **'Reset password failed. Please try again.'**
  String get resetPasswordError;

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
  /// **'Email not confirmed'**
  String get emailNotConfirmed;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please try again later.'**
  String get tooManyRequests;

  /// Email verification rate limit error
  ///
  /// In en, this message translates to:
  /// **'Too many verification emails have been requested. Please try again later.'**
  String get emailRateLimitExceeded;

  /// Label for login error
  ///
  /// In en, this message translates to:
  /// **'Unable to connect. Check your network and try again.'**
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

  /// Label for update password
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// Label for leaveGameConfirmation
  ///
  /// In en, this message translates to:
  /// **'Leave this game and return to the previous page?'**
  String get leaveGameConfirmation;

  /// Label for question bank
  ///
  /// In en, this message translates to:
  /// **'Question bank'**
  String get questionBank;

  /// Label for adminQuestionBank
  ///
  /// In en, this message translates to:
  /// **'Admin question bank'**
  String get adminQuestionBank;

  /// Label for myQuestionBank
  ///
  /// In en, this message translates to:
  /// **'My question bank'**
  String get myQuestionBank;

  /// Label for addQuestion
  ///
  /// In en, this message translates to:
  /// **'Add question'**
  String get addQuestion;

  /// Label for question
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// Label for correctAnswer
  ///
  /// In en, this message translates to:
  /// **'Correct answer'**
  String get correctAnswer;

  /// Label for questionGroup
  ///
  /// In en, this message translates to:
  /// **'Question group'**
  String get questionGroup;

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

  /// Label for scrambledWords
  ///
  /// In en, this message translates to:
  /// **'Words to rearrange'**
  String get scrambledWords;

  /// Label for speakingText
  ///
  /// In en, this message translates to:
  /// **'Text to speak'**
  String get speakingText;

  /// Label for requiredField
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get requiredField;

  /// Label for twoOptionsRequired
  ///
  /// In en, this message translates to:
  /// **'Enter at least two answer options'**
  String get twoOptionsRequired;

  /// Label for questionAdded
  ///
  /// In en, this message translates to:
  /// **'Question added to your question bank'**
  String get questionAdded;

  /// Label for grammarQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'For grammar questions, enter a complete sentence such as We are young; are becomes the blank automatically. For the plural category, enter only head and heads.'**
  String get grammarQuestionHelp;

  /// Label for sentenceQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter a complete word or correct sentence, such as mother or I love apples. It will be split into rearrangeable parts automatically.'**
  String get sentenceQuestionHelp;

  /// Label for grammarBaseWord
  ///
  /// In en, this message translates to:
  /// **'Base word (for example, head)'**
  String get grammarBaseWord;

  /// Label for completedGrammarQuestion
  ///
  /// In en, this message translates to:
  /// **'Complete question with the answer (for example, We are young)'**
  String get completedGrammarQuestion;

  /// Label for grammarAnswerMustAppear
  ///
  /// In en, this message translates to:
  /// **'The complete question must contain the correct answer so the blank can be created automatically.'**
  String get grammarAnswerMustAppear;

  /// Label for questionExample
  ///
  /// In en, this message translates to:
  /// **'Question example'**
  String get questionExample;

  /// Label for answerExample
  ///
  /// In en, this message translates to:
  /// **'Answer example'**
  String get answerExample;

  /// Label for sentenceOrWord
  ///
  /// In en, this message translates to:
  /// **'Complete word or correct sentence'**
  String get sentenceOrWord;

  /// Label for customQuestionGroup
  ///
  /// In en, this message translates to:
  /// **'+ Create a new category'**
  String get customQuestionGroup;

  /// Label for newQuestionGroup
  ///
  /// In en, this message translates to:
  /// **'New category name'**
  String get newQuestionGroup;

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

  /// Label for speakingQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the word or sentence the user should read aloud. Example: Nice to meet you.'**
  String get speakingQuestionHelp;

  /// Label for translationQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter the source text and its translation. Create at least 3 questions in the same group so the game can generate two incorrect choices.'**
  String get translationQuestionHelp;

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

  /// Label for wordSearchQuestionHelp
  ///
  /// In en, this message translates to:
  /// **'Enter an English word in Question and its meaning in Correct answer. Example: apple / 蘋果.'**
  String get wordSearchQuestionHelp;

  /// Label for duplicateQuestion
  ///
  /// In en, this message translates to:
  /// **'The same question and answer already exist in your selected question group.'**
  String get duplicateQuestion;

  /// Label for myQuestionBankEmpty
  ///
  /// In en, this message translates to:
  /// **'Your question bank has no questions available for this level. Add a question first.'**
  String get myQuestionBankEmpty;

  /// Label for threeQuestionsRequired
  ///
  /// In en, this message translates to:
  /// **'Each group in your question bank needs at least 3 questions before you can play.'**
  String get threeQuestionsRequired;

  /// Label for myQuestions
  ///
  /// In en, this message translates to:
  /// **'My questions'**
  String get myQuestions;

  /// Label for noMyQuestions
  ///
  /// In en, this message translates to:
  /// **'You have not added any questions for this game yet.'**
  String get noMyQuestions;

  /// Label for questionDeleted
  ///
  /// In en, this message translates to:
  /// **'Question deleted'**
  String get questionDeleted;

  /// Label for editQuestion
  ///
  /// In en, this message translates to:
  /// **'Edit question'**
  String get editQuestion;

  /// Label for questionUpdated
  ///
  /// In en, this message translates to:
  /// **'Question updated'**
  String get questionUpdated;

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
  /// **'Password must be at least 8 characters.'**
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

  /// Label for pageSelectorTooltip
  ///
  /// In en, this message translates to:
  /// **'Function menu'**
  String get pageSelectorTooltip;

  /// Label for userMenuButton
  ///
  /// In en, this message translates to:
  /// **'User Menu'**
  String get userMenuButton;

  /// Label for Home
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label for completeEventTitle
  ///
  /// In en, this message translates to:
  /// **'Complete the schedule'**
  String get completeEventTitle;

  /// Label for completeEventMessage
  ///
  /// In en, this message translates to:
  /// **'Once completed, this trip will disappear from today\'s list.'**
  String get completeEventMessage;

  /// Label for noInfoAvailable
  ///
  /// In en, this message translates to:
  /// **'No information available.'**
  String get noInfoAvailable;

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

  /// Label for selectAccount
  ///
  /// In en, this message translates to:
  /// **'Select account'**
  String get selectAccount;

  /// Label for personalEvent
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get personalEvent;

  /// Label for stock
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get stock;

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

  /// Label for group point accounts
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get pointGroup;

  /// Label for stockSelectDate
  ///
  /// In en, this message translates to:
  /// **'Stock date'**
  String get stockSelectDate;

  /// Label for statusInProgress
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// Label for statusNotStarted
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get statusNotStarted;

  /// Label for statusCompleted
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// Label for statusPending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// Label for noData
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// Label for accountMaster
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get accountMaster;

  /// Label for accountRecords
  ///
  /// In en, this message translates to:
  /// **'Account Records'**
  String get accountRecords;

  /// Label for todayIncomeExpense
  ///
  /// In en, this message translates to:
  /// **'Today\'s Income and Expenses'**
  String get todayIncomeExpense;

  /// Label for todayPoints
  ///
  /// In en, this message translates to:
  /// **'Today\'s Points'**
  String get todayPoints;

  /// Total amount of the selected account
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// Total points of the selected account
  ///
  /// In en, this message translates to:
  /// **'Total Points'**
  String get totalPoints;

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

  /// Game start button label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get gameStart;

  /// Empty game progress message
  ///
  /// In en, this message translates to:
  /// **'No game records'**
  String get gameNoRecords;

  /// Game level label
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get gameLevel;

  /// Game score label
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get gameScore;

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
  /// **'pageRecommendEvent'**
  String get pageRecommendEvent;

  /// Label for search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Tooltip for additional actions
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreActions;

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

  /// Label for add event
  ///
  /// In en, this message translates to:
  /// **'Add to calendar'**
  String get eventAdd1;

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

  /// Label for notSupportUpload
  ///
  /// In en, this message translates to:
  /// **'⚠️ Not support upload'**
  String get notSupportUpload;

  /// Label for noEventsToUpload
  ///
  /// In en, this message translates to:
  /// **'❌ No events to upload'**
  String get noEventsToUpload;

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

  /// Label for attraction business hours
  ///
  /// In en, this message translates to:
  /// **'Business hours'**
  String get businessHours;

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

  /// Shown when saving a duplicate event
  ///
  /// In en, this message translates to:
  /// **'This event already exists'**
  String get eventAlreadyExists;

  /// Shown when an event cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not save the event. Please try again later'**
  String get eventSaveFailed;

  /// Shown when a dashboard section cannot be loaded
  ///
  /// In en, this message translates to:
  /// **'Could not load this information. Please try again later'**
  String get dashboardLoadFailed;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Shown when an external website or map cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the link. Please try again later'**
  String get externalLinkOpenFailed;

  /// Shown when a dashboard selection cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not save the setting. Please try again later'**
  String get dashboardSettingSaveFailed;

  /// Shown when the account selector cannot load accounts
  ///
  /// In en, this message translates to:
  /// **'Could not load the account list. Please try again later'**
  String get accountListLoadFailed;

  /// Shown when there are no accounts to select
  ///
  /// In en, this message translates to:
  /// **'No account has been created yet. Create one before selecting it.'**
  String get accountListEmpty;

  /// Confirmation shown before leaving an edited form
  ///
  /// In en, this message translates to:
  /// **'Your changes have not been saved. Discard them?'**
  String get unsavedChangesPrompt;

  /// Button that discards unsaved form changes
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

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
  /// **'Delete failed'**
  String get deleteError;

  /// Label for todaySchedule
  ///
  /// In en, this message translates to:
  /// **'Today\'s schedule'**
  String get todaySchedule;

  /// Label for upcomingSchedule
  ///
  /// In en, this message translates to:
  /// **'Upcoming Schedule'**
  String get upcomingSchedule;

  /// Label for addToSchedule
  ///
  /// In en, this message translates to:
  /// **'Add to schedule'**
  String get addToSchedule;

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

  /// Weather forecast dialog title
  ///
  /// In en, this message translates to:
  /// **'Weather forecast'**
  String get weatherForecast;

  /// Weather temperature label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get weatherTemperature;

  /// Minimum weather temperature label
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get weatherMinimum;

  /// Maximum weather temperature label
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get weatherMaximum;

  /// Label for weatherThunderstorm
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// Label for weatherDrizzle
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

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

  /// Label for weatherMist
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get weatherMist;

  /// Label for weatherClear
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get weatherClear;

  /// Label for weatherClouds
  ///
  /// In en, this message translates to:
  /// **'Cloudy'**
  String get weatherClouds;

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

  /// Shown when alarm settings cannot be saved
  ///
  /// In en, this message translates to:
  /// **'Could not update the reminder. Please try again later'**
  String get alarmUpdateFailed;

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

  /// Label for postText
  ///
  /// In en, this message translates to:
  /// **'Post the full text'**
  String get postText;

  /// Label for parsing
  ///
  /// In en, this message translates to:
  /// **'Parsing'**
  String get parsing;

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

  /// Label for privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Label for terms of service
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// Label for account deletion request
  ///
  /// In en, this message translates to:
  /// **'Request account deletion'**
  String get requestAccountDeletion;

  /// Account deletion request explanation
  ///
  /// In en, this message translates to:
  /// **'We will open an email draft to submit your account deletion request. Your account and data will not be deleted immediately.'**
  String get accountDeletionRequestDescription;

  /// Label for continuing an action
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// Account deletion email fallback message
  ///
  /// In en, this message translates to:
  /// **'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.'**
  String get accountDeletionEmailUnavailable;

  /// Label for personal data export request
  ///
  /// In en, this message translates to:
  /// **'Request personal data export'**
  String get requestDataExport;

  /// Personal data export request explanation
  ///
  /// In en, this message translates to:
  /// **'We will open an email draft to submit your personal data export request. The export will be prepared after we verify the request.'**
  String get dataExportRequestDescription;

  /// Personal data export email fallback message
  ///
  /// In en, this message translates to:
  /// **'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.'**
  String get dataExportEmailUnavailable;

  /// Registration legal agreement prefix
  ///
  /// In en, this message translates to:
  /// **'I have read and agree to the '**
  String get agreeToLegalTermsPrefix;

  /// Registration legal agreement required message
  ///
  /// In en, this message translates to:
  /// **'Please agree to the Privacy Policy and Terms of Service before registering.'**
  String get acceptLegalTermsRequired;

  /// Connector between privacy policy and terms of service
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get legalTermsConnector;

  /// Short account menu label for data export
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get accountMenuDataExport;

  /// Short account menu label for account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountMenuAccountDeletion;

  /// Message shown when both legal documents have not been read
  ///
  /// In en, this message translates to:
  /// **'Please read both the Privacy Policy and Terms of Service before agreeing.'**
  String get readLegalTermsRequired;

  /// Confirmation shown when a legal document has been read
  ///
  /// In en, this message translates to:
  /// **'Reading complete'**
  String get legalDocumentReadComplete;

  /// Short status shown beside a legal document link after reading
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get legalDocumentRead;

  /// Registration success message
  ///
  /// In en, this message translates to:
  /// **'Registration successful.'**
  String get registrationSuccessful;

  /// Registration success message when email verification is required
  ///
  /// In en, this message translates to:
  /// **'Registration successful. Please verify your email before signing in.'**
  String get registrationVerificationRequired;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Password confirmation mismatch error
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordMismatch;

  /// Tooltip for showing a password
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// Tooltip for hiding a password
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// Message shown after a successful password update
  ///
  /// In en, this message translates to:
  /// **'Password updated. Please sign in with your new password.'**
  String get passwordUpdateSuccessful;

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

  /// Stock page background update failure status
  ///
  /// In en, this message translates to:
  /// **'The stock update failed. The last available data is still displayed.'**
  String get stockUpdateFailed;

  /// Stock page empty state
  ///
  /// In en, this message translates to:
  /// **'No stock data is currently available.'**
  String get stockNoData;

  /// Stock page initial load failure
  ///
  /// In en, this message translates to:
  /// **'Stock data could not be loaded. Please try again.'**
  String get stockLoadFailed;

  /// Load the latest stock data button
  ///
  /// In en, this message translates to:
  /// **'Load latest data'**
  String get stockRetry;

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

  /// Stock page thousand lots unit
  ///
  /// In en, this message translates to:
  /// **' thousand lots'**
  String get stockThousandLots;

  /// No description provided for @stockClosingPrice.
  ///
  /// In en, this message translates to:
  /// **'Closing price: {value}'**
  String stockClosingPrice(String value);

  /// No description provided for @stockTradingVolume.
  ///
  /// In en, this message translates to:
  /// **'Trading volume: {value} lots'**
  String stockTradingVolume(String value);

  /// Label for editRecord
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecord;

  /// Label for recordDate
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get recordDate;

  /// Label for recordValue
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get recordValue;

  /// Label for recordPrimaryCategory
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get recordPrimaryCategory;

  /// Label for recordSecondaryCategory
  ///
  /// In en, this message translates to:
  /// **'Custom subcategory (optional)'**
  String get recordSecondaryCategory;

  /// Label for recordCategoryUncategorized
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get recordCategoryUncategorized;

  /// Record category always included regardless of date
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get recordCategoryReserved;

  /// Label for recordCategoryFood
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get recordCategoryFood;

  /// Label for recordCategoryClothing
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get recordCategoryClothing;

  /// Label for recordCategoryHousing
  ///
  /// In en, this message translates to:
  /// **'Housing'**
  String get recordCategoryHousing;

  /// Label for recordCategoryTransportation
  ///
  /// In en, this message translates to:
  /// **'Transportation'**
  String get recordCategoryTransportation;

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

  /// Label for recordCategoryVirtue
  ///
  /// In en, this message translates to:
  /// **'Virtue'**
  String get recordCategoryVirtue;

  /// Label for recordCategoryIntelligence
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get recordCategoryIntelligence;

  /// Label for recordCategoryFitness
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get recordCategoryFitness;

  /// Label for recordCategorySocial
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get recordCategorySocial;

  /// Label for recordCategoryArts
  ///
  /// In en, this message translates to:
  /// **'Arts'**
  String get recordCategoryArts;

  /// Label for recordTotal
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get recordTotal;

  /// Label for recordPleaseConfirm
  ///
  /// In en, this message translates to:
  /// **'Please confirm'**
  String get recordPleaseConfirm;

  /// Label for recordSubmit
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get recordSubmit;

  /// Label for accountNew
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountNew;

  /// Label for accountName
  ///
  /// In en, this message translates to:
  /// **'Account name'**
  String get accountName;

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

  /// Label for accountAlreadyExists
  ///
  /// In en, this message translates to:
  /// **'Account already exists'**
  String get accountAlreadyExists;

  /// No description provided for @accountDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String accountDeleteConfirmation(String name);

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

  /// Label for accountingSpeechHint
  ///
  /// In en, this message translates to:
  /// **'For example: add/subtract an amount'**
  String get accountingSpeechHint;

  /// Label for pointsSpeechHint
  ///
  /// In en, this message translates to:
  /// **'For example: add/subtract points'**
  String get pointsSpeechHint;

  /// Label for accountingUnit
  ///
  /// In en, this message translates to:
  /// **''**
  String get accountingUnit;

  /// Label for pointsUnit
  ///
  /// In en, this message translates to:
  /// **'points'**
  String get pointsUnit;

  /// Recommended event refresh button
  ///
  /// In en, this message translates to:
  /// **'Update recommended events'**
  String get eventRefresh;

  /// Recommended event refresh success message
  ///
  /// In en, this message translates to:
  /// **'Recommended events updated.'**
  String get eventRefreshSucceeded;

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

  /// Shown when answer history prevents question deletion
  ///
  /// In en, this message translates to:
  /// **'This question has answer history and cannot be deleted. You can deactivate it instead.'**
  String get questionHasAnswersDeleteBlocked;

  /// Label for questionStatus
  ///
  /// In en, this message translates to:
  /// **'Question status'**
  String get questionStatus;

  /// Label for allQuestionStatuses
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get allQuestionStatuses;

  /// Label for activeQuestion
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeQuestion;

  /// Label for inactiveQuestion
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactiveQuestion;

  /// Label for deactivateQuestion
  ///
  /// In en, this message translates to:
  /// **'Deactivate question'**
  String get deactivateQuestion;

  /// Label for reactivateQuestion
  ///
  /// In en, this message translates to:
  /// **'Reactivate question'**
  String get reactivateQuestion;

  /// Label for questionDeactivated
  ///
  /// In en, this message translates to:
  /// **'Question deactivated.'**
  String get questionDeactivated;

  /// Label for questionReactivated
  ///
  /// In en, this message translates to:
  /// **'Question reactivated.'**
  String get questionReactivated;

  /// Label for questionStatusUpdateFailed
  ///
  /// In en, this message translates to:
  /// **'Question status could not be updated. Please try again.'**
  String get questionStatusUpdateFailed;

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

  /// Label for calendarSharing
  ///
  /// In en, this message translates to:
  /// **'Calendar sharing'**
  String get calendarSharing;

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

  /// Label for calendarSentInvitations
  ///
  /// In en, this message translates to:
  /// **'Sent invitations'**
  String get calendarSentInvitations;

  /// Label for calendarReceivedInvitations
  ///
  /// In en, this message translates to:
  /// **'Received invitations'**
  String get calendarReceivedInvitations;

  /// Label for calendarInvitationPending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get calendarInvitationPending;

  /// Label for calendarInvitationAccepted
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get calendarInvitationAccepted;

  /// Label for calendarInvitationDeclined
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get calendarInvitationDeclined;

  /// Label for calendarInvitationRevoked
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get calendarInvitationRevoked;

  /// Label for calendarInvitationAccept
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get calendarInvitationAccept;

  /// Label for calendarInvitationDecline
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get calendarInvitationDecline;

  /// Label for calendarInvitationRevoke
  ///
  /// In en, this message translates to:
  /// **'Stop sharing'**
  String get calendarInvitationRevoke;

  /// Label for calendarInvitationSent
  ///
  /// In en, this message translates to:
  /// **'Invitation sent.'**
  String get calendarInvitationSent;

  /// Label for calendarInvitationFailed
  ///
  /// In en, this message translates to:
  /// **'Calendar invitation could not be updated.'**
  String get calendarInvitationFailed;

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

  /// Label for calendarNoShareableEvents
  ///
  /// In en, this message translates to:
  /// **'There are no events available to share.'**
  String get calendarNoShareableEvents;

  /// Label for calendarStopReceiving
  ///
  /// In en, this message translates to:
  /// **'Stop viewing'**
  String get calendarStopReceiving;

  /// Label for calendarShareAllEvents
  ///
  /// In en, this message translates to:
  /// **'Share all events'**
  String get calendarShareAllEvents;

  /// Label for calendarNoSharedEvents
  ///
  /// In en, this message translates to:
  /// **'No events are currently shared.'**
  String get calendarNoSharedEvents;

  /// Label for calendarCancelSingleShare
  ///
  /// In en, this message translates to:
  /// **'Stop sharing this event'**
  String get calendarCancelSingleShare;

  /// Label for calendarCancelAllShares
  ///
  /// In en, this message translates to:
  /// **'Stop sharing all events'**
  String get calendarCancelAllShares;

  /// No description provided for @subscriptionUsage.
  ///
  /// In en, this message translates to:
  /// **'Used {used} / {quota}'**
  String subscriptionUsage(int used, int quota);

  /// No description provided for @subscriptionLocalUsage.
  ///
  /// In en, this message translates to:
  /// **'Stored on this device: {used} / Unlimited'**
  String subscriptionLocalUsage(int used);

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

  /// Label for subscriptionImagePlusOnly
  ///
  /// In en, this message translates to:
  /// **'Photo uploads are available with Plus.'**
  String get subscriptionImagePlusOnly;

  /// Label for subscriptionDeleteRecordHint
  ///
  /// In en, this message translates to:
  /// **'Deleting this record will also recalculate today and total values.'**
  String get subscriptionDeleteRecordHint;

  /// Label for dataStorageTitle
  ///
  /// In en, this message translates to:
  /// **'Where should new personal data be saved?'**
  String get dataStorageTitle;

  /// Label for dataStorageCloud
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get dataStorageCloud;

  /// Label for dataStorageLocal
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get dataStorageLocal;

  /// Label for dataStorageLocalWarning
  ///
  /// In en, this message translates to:
  /// **'Local data is visible only on this device, browser, and browser profile. It will not automatically appear on another device, browser, or profile. Removing the app or clearing site or browser data may permanently delete it. It can be moved to the cloud when it fits your plan limits.'**
  String get dataStorageLocalWarning;

  /// Label for dataStorageCloudWarning
  ///
  /// In en, this message translates to:
  /// **'Cloud data is available across devices and is subject to your plan limits.'**
  String get dataStorageCloudWarning;

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

  /// Label for dataMoveToLocalSuccess
  ///
  /// In en, this message translates to:
  /// **'Cloud data was moved to this device.'**
  String get dataMoveToLocalSuccess;

  /// Label for dataMoveToLocalFailed
  ///
  /// In en, this message translates to:
  /// **'Some data could not be moved. Cloud originals were retained.'**
  String get dataMoveToLocalFailed;

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

  /// Label for dataUploadToCloudSuccess
  ///
  /// In en, this message translates to:
  /// **'Local data was uploaded to the cloud.'**
  String get dataUploadToCloudSuccess;

  /// Label for dataUploadToCloudFailed
  ///
  /// In en, this message translates to:
  /// **'The upload was cancelled. All local records remain on this device.'**
  String get dataUploadToCloudFailed;

  /// No description provided for @dataUploadQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Upload cancelled: {resource} currently uses {used} cloud records; this upload adds {incoming}, but the plan limit is {quota}.'**
  String dataUploadQuotaExceeded(String resource, int used, int incoming, int quota);

  /// No description provided for @subscriptionRenewalRequired.
  ///
  /// In en, this message translates to:
  /// **'Your paid period has ended. Cloud data is read-only until you renew or move all cloud data to this device.'**
  String get subscriptionRenewalRequired;
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
