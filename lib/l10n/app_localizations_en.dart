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
  String resetPasswordCooldown(int seconds) {
    return 'Retry in ${seconds}s';
  }

  @override
  String get noEmailError => 'Please enter your email address.';

  @override
  String get invalidEmail => 'Account format error';

  @override
  String get noPasswordError => 'Please enter your password.';

  @override
  String get noRecoverySession => 'The system cannot find a valid [verification credential], or the credential has expired.';

  @override
  String get resetPasswordError => 'Reset password failed. Please try again.';

  @override
  String get resetPasswordEmailNotFound => 'Account not found';

  @override
  String get wrongUserPassword => 'User or Password is wrong';

  @override
  String get emailNotConfirmed => 'Email not confirmed';

  @override
  String get tooManyRequests => 'Too many requests. Please try again later.';

  @override
  String get emailRateLimitExceeded => 'Too many verification emails have been requested. Please try again later.';

  @override
  String get networkError => 'Unable to connect. Check your network and try again.';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get register => '  Register  ';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get leaveGameConfirmation => 'Leave this game and return to the previous page?';

  @override
  String get questionBank => 'Question bank';

  @override
  String get adminQuestionBank => 'Admin question bank';

  @override
  String get myQuestionBank => 'My question bank';

  @override
  String get addQuestion => 'Add question';

  @override
  String get question => 'Question';

  @override
  String get correctAnswer => 'Correct answer';

  @override
  String get questionGroup => 'Question group';

  @override
  String get answerOptions => 'Answer options';

  @override
  String get answerOptionsHint => 'Separate options with commas';

  @override
  String get scrambledWords => 'Words to rearrange';

  @override
  String get speakingText => 'Text to speak';

  @override
  String get requiredField => 'This field is required';

  @override
  String get twoOptionsRequired => 'Enter at least two answer options';

  @override
  String get questionAdded => 'Question added to your question bank';

  @override
  String get grammarQuestionHelp => 'For grammar questions, enter a complete sentence such as We are young; are becomes the blank automatically. For the plural category, enter only head and heads.';

  @override
  String get sentenceQuestionHelp => 'Enter a complete word or correct sentence, such as mother or I love apples. It will be split into rearrangeable parts automatically.';

  @override
  String get grammarBaseWord => 'Base word (for example, head)';

  @override
  String get completedGrammarQuestion => 'Complete question with the answer (for example, We are young)';

  @override
  String get grammarAnswerMustAppear => 'The complete question must contain the correct answer so the blank can be created automatically.';

  @override
  String get questionExample => 'Question example';

  @override
  String get answerExample => 'Answer example';

  @override
  String get sentenceOrWord => 'Complete word or correct sentence';

  @override
  String get customQuestionGroup => '+ Create a new category';

  @override
  String get newQuestionGroup => 'New category name';

  @override
  String get questionGroupLevelNumber => 'Level number after the category (blank means 1)';

  @override
  String get questionGroupLevelRange => 'The level number must be between 1 and 30.';

  @override
  String get speakingQuestionHelp => 'Enter the word or sentence the user should read aloud. Example: Nice to meet you.';

  @override
  String get translationQuestionHelp => 'Enter the source text and its translation. Create at least 3 questions in the same group so the game can generate two incorrect choices.';

  @override
  String get japaneseTranslationQuestionHelp => 'Enter Japanese in Question and its translation in Correct answer. Create at least 3 questions in the same group.';

  @override
  String get koreanTranslationQuestionHelp => 'Enter Korean in Question and its translation in Correct answer. Create at least 3 questions in the same group.';

  @override
  String get wordSearchQuestionHelp => 'Enter an English word in Question and its meaning in Correct answer. Example: apple / 蘋果.';

  @override
  String get duplicateQuestion => 'The same question and answer already exist in your selected question group.';

  @override
  String get myQuestionBankEmpty => 'Your question bank has no questions available for this level. Add a question first.';

  @override
  String get threeQuestionsRequired => 'Each group in your question bank needs at least 3 questions before you can play.';

  @override
  String get myQuestions => 'My questions';

  @override
  String get noMyQuestions => 'You have not added any questions for this game yet.';

  @override
  String get questionDeleted => 'Question deleted';

  @override
  String get editQuestion => 'Edit question';

  @override
  String get questionUpdated => 'Question updated';

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
  String get weakPassword => 'Password must be at least 8 characters.';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => 'Settings';

  @override
  String get pageSelectorTooltip => 'Function menu';

  @override
  String get userMenuButton => 'User Menu';

  @override
  String get home => 'Home';

  @override
  String get completeEventTitle => 'Complete the schedule';

  @override
  String get completeEventMessage => 'Once completed, this trip will disappear from today\'s list.';

  @override
  String get noInfoAvailable => 'No information available.';

  @override
  String get openMap => 'Navigation';

  @override
  String get selectCity => 'Select city';

  @override
  String get selectAccount => 'Select account';

  @override
  String get personalEvent => 'Personal';

  @override
  String get stock => 'Stock';

  @override
  String get recommendEvent => 'Event';

  @override
  String get recommendEventZero => 'No event';

  @override
  String get recommendPlaces => 'Attractions';

  @override
  String get recommendPlacesZero => 'No recommended places at the moment';

  @override
  String get memoryTrace => 'Memory Trace';

  @override
  String get memoryTraceZero => 'Go add some memories!';

  @override
  String get accountPersonal => 'Personal';

  @override
  String get accountProject => 'Journey';

  @override
  String get accountMaster => 'Master';

  @override
  String get accountRecords => 'Account Records';

  @override
  String get todayIncomeExpense => 'Today\'s Income and Expenses';

  @override
  String get todayPoints => 'Today\'s Points';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get totalPoints => 'Total Points';

  @override
  String get pointsRecord => 'Points Record';

  @override
  String get game => 'Game';

  @override
  String get gameStart => 'Start';

  @override
  String get gameNoRecords => 'No game records';

  @override
  String get gameLevel => 'Level';

  @override
  String get gameScore => 'Score';

  @override
  String get ai => 'AI';

  @override
  String get feedback => 'Feedback';

  @override
  String get businessPlan => 'Business Plan';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get search => 'Search';

  @override
  String get moreActions => 'More';

  @override
  String get toggleView => 'Toggle View';

  @override
  String get exportExcel => 'Export';

  @override
  String get eventAdd => 'Add';

  @override
  String get eventAdd1 => 'Add to calendar';

  @override
  String get eventAddOk => '✅ Event added';

  @override
  String get eventAddError => 'Add it repeatedly';

  @override
  String get memoryAdd => 'Add Memory';

  @override
  String get memoryAddOk => '✅ Memory Added';

  @override
  String get memoryAddError => 'Do you want to add the memory again';

  @override
  String get uploadExcel => 'Upload Csv';

  @override
  String get uploadFailed => '❌ Upload failed';

  @override
  String get uploadInProgress => '❌ The previous file upload is still in progress.';

  @override
  String get uploadSuccess => '✅ Upload successful';

  @override
  String get notSupportUpload => '⚠️ Not support upload';

  @override
  String get noEventsToUpload => '❌ No events to upload';

  @override
  String get noEventsToExport => '❌ No events to export';

  @override
  String get exportFailed => '❌ Export failed';

  @override
  String get exportInProgress => '❌ The previous file export is still in progress.';

  @override
  String get exportSuccess => '✅ Export successful';

  @override
  String get notSupportExport => '⚠️ Not support export';

  @override
  String get excelColumnHeaderId => 'Activity id_______________________';

  @override
  String get excelColumnHeaderMasterUrl => 'Activity url_______________________';

  @override
  String get excelColumnHeaderActivityName => 'Activity name_______________________';

  @override
  String get excelColumnHeaderKeywords => 'Keywords_______________________';

  @override
  String get excelColumnHeaderCity => 'City';

  @override
  String get excelColumnHeaderLocation => 'Location____________________';

  @override
  String get excelColumnHeaderFee => 'Fee';

  @override
  String get excelColumnHeaderStartDate => 'Start Date__';

  @override
  String get excelColumnHeaderStartTime => 'Start Time';

  @override
  String get excelColumnHeaderEndDate => 'End Date__';

  @override
  String get excelColumnHeaderEndTime => 'End Time';

  @override
  String get excelColumnHeaderDescription => 'Description______';

  @override
  String get excelColumnHeaderSponsor => 'Sponsor';

  @override
  String get excelColumnHeaderAgeMin => 'Min. Age';

  @override
  String get excelColumnHeaderAgeMax => 'Max Age';

  @override
  String get excelColumnHeaderIsFree => 'Free ?';

  @override
  String get excelColumnHeaderPriceMin => 'Min. Price';

  @override
  String get excelColumnHeaderPriceMax => 'Max Price';

  @override
  String get excelColumnHeaderIsOutdoor => 'Outdoor ?';

  @override
  String get downloaded => '✅ Downloaded';

  @override
  String get activityName => 'Activity name';

  @override
  String get keywords => 'Keywords';

  @override
  String get city => 'City';

  @override
  String get location => 'Location';

  @override
  String get fee => 'Fee';

  @override
  String get startDate => 'Start date';

  @override
  String get startTime => 'Start time';

  @override
  String get endDate => 'End date';

  @override
  String get endTime => 'End time';

  @override
  String get description => 'Description';

  @override
  String get sponsor => 'Sponsor';

  @override
  String get ageMin => 'Min. Age';

  @override
  String get ageMax => 'Max Age';

  @override
  String get priceMin => 'Min. Price';

  @override
  String get priceMax => 'Max Price';

  @override
  String get isFree => 'Free ?';

  @override
  String get isOutdoor => 'Outdoor ?';

  @override
  String get toBeDetermined => 'To Be Determined';

  @override
  String get free => 'Free';

  @override
  String get pay => 'Pay';

  @override
  String get outdoor => 'Outdoor';

  @override
  String get indoor => 'Indoor';

  @override
  String get masterUrl => 'Link';

  @override
  String get subUrl => 'Link';

  @override
  String get eventSaved => '✅ Event saved';

  @override
  String get eventSaveError => 'Activity name cannot be empty';

  @override
  String get eventAlreadyExists => 'This event already exists';

  @override
  String get eventSaveFailed => 'Could not save the event. Please try again later';

  @override
  String get dashboardLoadFailed => 'Could not load this information. Please try again later';

  @override
  String get retry => 'Retry';

  @override
  String get externalLinkOpenFailed => 'Could not open the link. Please try again later';

  @override
  String get dashboardSettingSaveFailed => 'Could not save the setting. Please try again later';

  @override
  String get accountListLoadFailed => 'Could not load the account list. Please try again later';

  @override
  String get accountListEmpty => 'No account has been created yet. Create one before selecting it.';

  @override
  String get unsavedChangesPrompt => 'Your changes have not been saved. Discard them?';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String get eventAddEdit => 'Add/Edit';

  @override
  String get eventAddSub => 'Add detailed activities';

  @override
  String get eventSub => 'Detailed activities';

  @override
  String get save => 'Save';

  @override
  String get searchKeywords => 'Keyword (comma separated)';

  @override
  String get dateClear => 'Date clear';

  @override
  String get add => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get review => 'Review';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get like => 'Like';

  @override
  String get dislike => 'Dislike';

  @override
  String get eventDelete => 'Delete event';

  @override
  String get deleteOk => '✅ Deletion completed';

  @override
  String get deleteError => 'Delete failed';

  @override
  String get todaySchedule => 'Today\'s schedule';

  @override
  String get upcomingSchedule => 'Upcoming Schedule';

  @override
  String get addToSchedule => 'Add to schedule';

  @override
  String get clickHereToSeeMore => 'See more...';

  @override
  String get close => 'Close';

  @override
  String get weatherForecast => 'Weather forecast';

  @override
  String get weatherTemperature => 'Temperature';

  @override
  String get weatherMinimum => 'Low';

  @override
  String get weatherMaximum => 'High';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherDrizzle => 'Drizzle';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherMist => 'Mist';

  @override
  String get weatherClear => 'Clear';

  @override
  String get weatherClouds => 'Cloudy';

  @override
  String get url => 'URL';

  @override
  String get speak => 'Voice input';

  @override
  String get speakUp => 'Speak up';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get weekDaySun => 'Sun';

  @override
  String get weekDayMon => 'Mon';

  @override
  String get weekDayTue => 'Tue';

  @override
  String get weekDayWed => 'Wed';

  @override
  String get weekDayThu => 'Thu';

  @override
  String get weekDayFri => 'Fri';

  @override
  String get weekDaySat => 'Sat';

  @override
  String get year => 'Year';

  @override
  String get month => 'Month';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmDelete => 'Confirm delete?';

  @override
  String get setAlarm => 'Set alarm';

  @override
  String get cancelAlarm => 'Cancel alarm';

  @override
  String get setAlarmCompleted => '✅ Set alarm completed';

  @override
  String get alarmUpdateFailed => 'Could not update the reminder. Please try again later';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get today => 'Today';

  @override
  String get nextMonth => 'Next month';

  @override
  String get postText => 'Post the full text';

  @override
  String get parsing => 'Parsing';

  @override
  String get clear => 'Clear';

  @override
  String get repeatOptions => 'Repeat times';

  @override
  String get repeatOptionsOnce => 'Once';

  @override
  String get repeatOptionsEveryDay => 'Every day';

  @override
  String get repeatOptionsEveryWeek => 'Every week';

  @override
  String get repeatOptionsEveryTwoWeeks => 'Every two weeks';

  @override
  String get repeatOptionsEveryMonth => 'Every month';

  @override
  String get repeatOptionsEveryTwoMonths => 'Every two months';

  @override
  String get repeatOptionsEveryYear => 'Every year';

  @override
  String get repeatOptionsEvery => 'Every';

  @override
  String get reminderOptions => 'Reminder time';

  @override
  String get reminderOptions15MinutesBefore => '15 minutes before';

  @override
  String get reminderOptions30MinutesBefore => '30 minutes before';

  @override
  String get reminderOptionsOneHourBefore => '1 hour before';

  @override
  String get reminderOptionsDefaultSameDay8am => 'Sam day 8 am';

  @override
  String get reminderOptionsDefaultDayBefore8am => '1 day before 8 am';

  @override
  String get reminderOptionsTwoDaysBefore => '2 days before';

  @override
  String get reminderOptionsOneWeekBefore => '1 week before';

  @override
  String get reminderOptionsTwoWeeksBefore => '2 weeks before';

  @override
  String get reminderOptionsOneMonthBefore => '1 month before';

  @override
  String get eventReminder => 'Event reminder';

  @override
  String get eventReminderToday => 'Today event reminder';

  @override
  String get eventReminderDesc => 'Remind you of upcoming events';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get requestAccountDeletion => 'Request account deletion';

  @override
  String get accountDeletionRequestDescription => 'We will open an email draft to submit your account deletion request. Your account and data will not be deleted immediately.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get accountDeletionEmailUnavailable => 'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.';

  @override
  String get requestDataExport => 'Request personal data export';

  @override
  String get dataExportRequestDescription => 'We will open an email draft to submit your personal data export request. The export will be prepared after we verify the request.';

  @override
  String get dataExportEmailUnavailable => 'Unable to open your email app. Please email minavi@alumni.nccu.edu.tw.';

  @override
  String get agreeToLegalTermsPrefix => 'I have read and agree to the ';

  @override
  String get acceptLegalTermsRequired => 'Please agree to the Privacy Policy and Terms of Service before registering.';

  @override
  String get legalTermsConnector => ' and ';

  @override
  String get accountMenuDataExport => 'Export data';

  @override
  String get accountMenuAccountDeletion => 'Delete account';

  @override
  String get readLegalTermsRequired => 'Please read both the Privacy Policy and Terms of Service before agreeing.';

  @override
  String get legalDocumentReadComplete => 'Reading complete';

  @override
  String get legalDocumentRead => 'Read';

  @override
  String get registrationSuccessful => 'Registration successful.';

  @override
  String get registrationVerificationRequired => 'Registration successful. Please verify your email before signing in.';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordMismatch => 'Passwords do not match.';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get passwordUpdateSuccessful => 'Password updated. Please sign in with your new password.';

  @override
  String get stockUpdateInProgress => 'Stock data and model are updating. New results will appear automatically.';

  @override
  String get stockUpdateSucceeded => 'Stock data and model update completed.';

  @override
  String get stockUpdateFailed => 'The stock update failed. The last available data is still displayed.';

  @override
  String get stockNoData => 'No stock data is currently available.';

  @override
  String get stockLoadFailed => 'Stock data could not be loaded. Please try again.';

  @override
  String get stockRetry => 'Try again';

  @override
  String get stockDashboardTitle => '📊 Market dashboard';

  @override
  String get stockForeignBuyTop30 => 'Net foreign buy ranking';

  @override
  String get stockForeignSellTop30 => 'Net foreign sell ranking';

  @override
  String get stockThousandLots => ' thousand lots';

  @override
  String stockClosingPrice(String value) {
    return 'Closing price: $value';
  }

  @override
  String stockTradingVolume(String value) {
    return 'Trading volume: $value lots';
  }

  @override
  String get editRecord => 'Edit record';

  @override
  String get recordDate => 'Date';

  @override
  String get recordValue => 'Value';

  @override
  String get recordPrimaryCategory => 'Category';

  @override
  String get recordSecondaryCategory => 'Custom subcategory (optional)';

  @override
  String get recordCategoryUncategorized => 'Uncategorized';

  @override
  String get recordCategoryFood => 'Food';

  @override
  String get recordCategoryClothing => 'Clothing';

  @override
  String get recordCategoryHousing => 'Housing';

  @override
  String get recordCategoryTransportation => 'Transportation';

  @override
  String get recordCategoryEducation => 'Education';

  @override
  String get recordCategoryEntertainment => 'Entertainment';

  @override
  String get recordCategoryVirtue => 'Virtue';

  @override
  String get recordCategoryIntelligence => 'Intelligence';

  @override
  String get recordCategoryFitness => 'Fitness';

  @override
  String get recordCategorySocial => 'Social';

  @override
  String get recordCategoryArts => 'Arts';

  @override
  String get recordTotal => 'Total';

  @override
  String get recordPleaseConfirm => 'Please confirm';

  @override
  String get recordSubmit => 'Submit';

  @override
  String get accountNew => 'New account';

  @override
  String get accountName => 'Account name';

  @override
  String get accountCreate => 'Create';

  @override
  String get accountDefault => 'Default';

  @override
  String get accountAlreadyExists => 'Account already exists';

  @override
  String accountDeleteConfirmation(String name) {
    return 'Delete $name?';
  }

  @override
  String get accountSetMainCurrency => 'Set main currency';

  @override
  String get accountSwitchCurrency => 'Switch currency';

  @override
  String get accountingSpeechHint => 'For example: add/subtract an amount';

  @override
  String get pointsSpeechHint => 'For example: add/subtract points';

  @override
  String get accountingUnit => '';

  @override
  String get pointsUnit => 'points';

  @override
  String get eventRefresh => 'Update recommended events';

  @override
  String get eventRefreshSucceeded => 'Recommended events updated.';

  @override
  String get eventRefreshFailed => 'Could not update recommended events. Try again later.';

  @override
  String get eventRefreshRunning => 'Recommended events are being updated. Please check again later.';

  @override
  String get questionHasAnswersDeleteBlocked => 'This question has answer history and cannot be deleted. You can deactivate it instead.';

  @override
  String get questionStatus => 'Question status';

  @override
  String get allQuestionStatuses => 'All statuses';

  @override
  String get activeQuestion => 'Active';

  @override
  String get inactiveQuestion => 'Inactive';

  @override
  String get deactivateQuestion => 'Deactivate question';

  @override
  String get reactivateQuestion => 'Reactivate question';

  @override
  String get questionDeactivated => 'Question deactivated.';

  @override
  String get questionReactivated => 'Question reactivated.';

  @override
  String get questionStatusUpdateFailed => 'Question status could not be updated. Please try again.';

  @override
  String get mapCoordinateBackfill => 'Fill map coordinates';

  @override
  String get mapCoordinateBackfillFailed => 'Could not fill map coordinates. Try again later.';

  @override
  String mapCoordinateBackfillResult(int saved, int remaining, String coverage) {
    return 'Saved $saved; $remaining remaining; coverage $coverage%.';
  }
}
