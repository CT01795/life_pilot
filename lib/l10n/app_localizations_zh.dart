// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '生活導航';

  @override
  String get language => '語言';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get login => '  登入  ';

  @override
  String get loginAnonymously => '訪客登入';

  @override
  String get logout => '登出';

  @override
  String get resetPassword => '重設密碼';

  @override
  String get resetPasswordEmail => '重設密碼信已寄出，請檢查信箱。';

  @override
  String resetPasswordCooldown(int seconds) {
    return '$seconds 秒後可重寄';
  }

  @override
  String get noEmailError => '請輸入帳號';

  @override
  String get invalidEmail => '帳號格式錯誤';

  @override
  String get noPasswordError => '請輸入密碼';

  @override
  String get noRecoverySession => '系統找不到有效的「驗證憑證」或該憑證已經過期';

  @override
  String get resetPasswordError => '重設密碼失敗，請再試一次。';

  @override
  String get resetPasswordEmailNotFound => '帳號未註冊';

  @override
  String get wrongUserPassword => '帳號密碼錯誤';

  @override
  String get emailNotConfirmed => '帳號尚未驗證';

  @override
  String get tooManyRequests => '操作過於頻繁，請稍後再試。';

  @override
  String get emailRateLimitExceeded => '驗證信寄送次數過多，請稍後再試。';

  @override
  String get networkError => '無法連線，請檢查網路後再試。';

  @override
  String get email => '電子郵件';

  @override
  String get password => '密碼';

  @override
  String get register => '  註冊  ';

  @override
  String get updatePassword => '更新密碼';

  @override
  String get back => '返回';

  @override
  String get loginError => '登入失敗，請再試一次。';

  @override
  String get logoutError => '登出失敗，請再試一次。';

  @override
  String get registerError => '註冊失敗，請再試一次。';

  @override
  String get emailAlreadyInUse => '帳號已經被人註冊。';

  @override
  String get weakPassword => '密碼長度必須至少為 8 個字元';

  @override
  String get unknownError => '未知的錯誤';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '設定';

  @override
  String get pageSelectorTooltip => '功能選單';

  @override
  String get userMenuButton => '使用者選單';

  @override
  String get home => '首頁';

  @override
  String get completeEventTitle => '完成行程';

  @override
  String get completeEventMessage => '完成後此行程會從今日列表消失';

  @override
  String get noInfoAvailable => '沒有資料';

  @override
  String get openMap => '導航';

  @override
  String get selectCity => '選擇城市';

  @override
  String get selectAccount => '選擇帳號';

  @override
  String get personalEvent => '行事曆';

  @override
  String get stock => '股票';

  @override
  String get recommendEvent => '推薦活動';

  @override
  String get recommendEventZero => '目前沒有推薦活動';

  @override
  String get recommendPlaces => '推薦景點';

  @override
  String get recommendPlacesZero => '目前沒有推薦景點';

  @override
  String get memoryTrace => '回憶走廊';

  @override
  String get memoryTraceZero => '去創造更多回憶吧！';

  @override
  String get accountPersonal => '個人';

  @override
  String get accountProject => '旅程';

  @override
  String get accountMaster => '總帳戶';

  @override
  String get accountRecords => '記帳';

  @override
  String get todayIncomeExpense => '今日收支';

  @override
  String get todayPoints => '今日積分';

  @override
  String get pointsRecord => '積分';

  @override
  String get game => '遊戲';

  @override
  String get ai => 'AI助理';

  @override
  String get feedback => '意見回饋';

  @override
  String get businessPlan => 'Business Plan';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get search => '搜尋';

  @override
  String get toggleView => '切換檢視模式';

  @override
  String get exportExcel => '匯出 Excel';

  @override
  String get eventAdd => '新增活動';

  @override
  String get eventAdd1 => '行事曆新增活動';

  @override
  String get eventAddOk => '✅ 已新增活動';

  @override
  String get eventAddError => '要重複新增活動嗎';

  @override
  String get memoryAdd => '新增回憶';

  @override
  String get memoryAddOk => '✅ 已新增回憶';

  @override
  String get memoryAddError => '要重複新增回憶嗎';

  @override
  String get uploadExcel => '上傳 Csv';

  @override
  String get uploadFailed => '❌ 上傳失敗';

  @override
  String get uploadInProgress => '❌ 前次上傳尚在執行中';

  @override
  String get uploadSuccess => '✅ 上傳成功';

  @override
  String get notSupportUpload => '⚠️ 此平台尚未支援上傳';

  @override
  String get noEventsToUpload => '❌ 沒有可上傳的活動';

  @override
  String get noEventsToExport => '❌ 沒有可匯出的活動';

  @override
  String get exportFailed => '❌ 匯出失敗';

  @override
  String get exportInProgress => '❌ 前次匯出尚在執行中';

  @override
  String get exportSuccess => '✅ 匯出成功';

  @override
  String get notSupportExport => '⚠️ 此平台尚未支援匯出';

  @override
  String get excelColumnHeaderId => '活動 id_______________________';

  @override
  String get excelColumnHeaderMasterUrl => '活動網址_______________________';

  @override
  String get excelColumnHeaderActivityName => '活動名稱_______________________';

  @override
  String get excelColumnHeaderKeywords => '關鍵字_______________________';

  @override
  String get excelColumnHeaderCity => '縣市';

  @override
  String get excelColumnHeaderLocation => '地點____________________';

  @override
  String get excelColumnHeaderFee => '費用';

  @override
  String get excelColumnHeaderStartDate => '開始日期__';

  @override
  String get excelColumnHeaderStartTime => '開始時間';

  @override
  String get excelColumnHeaderEndDate => '結束日期__';

  @override
  String get excelColumnHeaderEndTime => '結束時間';

  @override
  String get excelColumnHeaderDescription => '描述______';

  @override
  String get excelColumnHeaderSponsor => '相關單位';

  @override
  String get excelColumnHeaderAgeMin => '最低年齡';

  @override
  String get excelColumnHeaderAgeMax => '最大年齡';

  @override
  String get excelColumnHeaderIsFree => '免費 ?';

  @override
  String get excelColumnHeaderPriceMin => '最低價格';

  @override
  String get excelColumnHeaderPriceMax => '最高價格';

  @override
  String get excelColumnHeaderIsOutdoor => '戶外 ?';

  @override
  String get downloaded => '✅ 已下載';

  @override
  String get activityName => '活動名稱';

  @override
  String get keywords => '關鍵字';

  @override
  String get city => '縣市';

  @override
  String get location => '地點';

  @override
  String get fee => '費用';

  @override
  String get startDate => '開始日期';

  @override
  String get startTime => '開始時間';

  @override
  String get endDate => '結束日期';

  @override
  String get endTime => '結束時間';

  @override
  String get description => '描述';

  @override
  String get sponsor => '相關單位';

  @override
  String get ageMin => '最低年齡';

  @override
  String get ageMax => '最大年齡';

  @override
  String get priceMin => '最低價格';

  @override
  String get priceMax => '最高價格';

  @override
  String get isFree => '免費 ?';

  @override
  String get isOutdoor => '室外 ?';

  @override
  String get toBeDetermined => '待定';

  @override
  String get free => '免費';

  @override
  String get pay => '付費';

  @override
  String get outdoor => '戶外';

  @override
  String get indoor => '室內';

  @override
  String get masterUrl => '連結';

  @override
  String get subUrl => '連結';

  @override
  String get eventSaved => '✅ 活動已儲存';

  @override
  String get eventSaveError => '活動名稱不可為空';

  @override
  String get eventAlreadyExists => '此活動已存在';

  @override
  String get eventSaveFailed => '活動儲存失敗，請稍後再試';

  @override
  String get dashboardLoadFailed => '資料載入失敗，請稍後再試';

  @override
  String get retry => '重試';

  @override
  String get externalLinkOpenFailed => '無法開啟連結，請稍後再試';

  @override
  String get dashboardSettingSaveFailed => '設定儲存失敗，請稍後再試';

  @override
  String get accountListLoadFailed => '帳戶清單載入失敗，請稍後再試';

  @override
  String get accountListEmpty => '尚未建立帳戶，請先建立帳戶後再選擇。';

  @override
  String get unsavedChangesPrompt => '變更尚未儲存，確定要捨棄嗎？';

  @override
  String get discardChanges => '捨棄變更';

  @override
  String get eventAddEdit => '新增／編輯活動';

  @override
  String get eventAddSub => '新增細項';

  @override
  String get eventSub => '細項活動';

  @override
  String get save => '儲存';

  @override
  String get searchKeywords => '關鍵字搜尋(逗點分隔)';

  @override
  String get dateClear => '清除日期';

  @override
  String get add => '新增';

  @override
  String get edit => '編輯';

  @override
  String get review => '審核';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get like => '喜歡';

  @override
  String get dislike => '不喜歡';

  @override
  String get eventDelete => '刪除活動';

  @override
  String get deleteOk => '✅ 刪除完成';

  @override
  String get deleteError => '刪除失敗';

  @override
  String get todaySchedule => '今日行程';

  @override
  String get upcomingSchedule => '近日行程';

  @override
  String get addToSchedule => '加入行程';

  @override
  String get clickHereToSeeMore => '點我看更多';

  @override
  String get close => '關閉';

  @override
  String get url => '網址';

  @override
  String get speak => '語音輸入';

  @override
  String get speakUp => '說出來';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get weekDaySun => '日';

  @override
  String get weekDayMon => '一';

  @override
  String get weekDayTue => '二';

  @override
  String get weekDayWed => '三';

  @override
  String get weekDayThu => '四';

  @override
  String get weekDayFri => '五';

  @override
  String get weekDaySat => '六';

  @override
  String get year => '年';

  @override
  String get month => '月';

  @override
  String get confirm => '確定';

  @override
  String get confirmDelete => '確定刪除?';

  @override
  String get setAlarm => '設定鬧鐘';

  @override
  String get cancelAlarm => '取消鬧鐘';

  @override
  String get setAlarmCompleted => '✅ 設定鬧鐘完成';

  @override
  String get alarmUpdateFailed => '提醒設定失敗，請稍後再試';

  @override
  String get previousMonth => '上一個月';

  @override
  String get today => '今日';

  @override
  String get nextMonth => '下一個月';

  @override
  String get postText => '貼上活動全文...';

  @override
  String get parsing => '解析';

  @override
  String get clear => '清除';

  @override
  String get repeatOptions => '重複次數';

  @override
  String get repeatOptionsOnce => '僅一次';

  @override
  String get repeatOptionsEveryDay => '每天';

  @override
  String get repeatOptionsEveryWeek => '每週';

  @override
  String get repeatOptionsEveryTwoWeeks => '每兩週';

  @override
  String get repeatOptionsEveryMonth => '每月';

  @override
  String get repeatOptionsEveryTwoMonths => '每兩個月';

  @override
  String get repeatOptionsEveryYear => '每年';

  @override
  String get repeatOptionsEvery => '每';

  @override
  String get reminderOptions => '提醒時間';

  @override
  String get reminderOptions15MinutesBefore => '15分鐘前';

  @override
  String get reminderOptions30MinutesBefore => '30分鐘前';

  @override
  String get reminderOptionsOneHourBefore => '1小時前';

  @override
  String get reminderOptionsDefaultSameDay8am => '當天早上8點';

  @override
  String get reminderOptionsDefaultDayBefore8am => '前1天早上8點';

  @override
  String get reminderOptionsTwoDaysBefore => '2天前';

  @override
  String get reminderOptionsOneWeekBefore => '1週前';

  @override
  String get reminderOptionsTwoWeeksBefore => '2週前';

  @override
  String get reminderOptionsOneMonthBefore => '1個月前';

  @override
  String get eventReminder => '活動提醒';

  @override
  String get eventReminderToday => '今日活動提醒';

  @override
  String get eventReminderDesc => '提醒你即將開始的活動';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get termsOfService => '服務條款';

  @override
  String get requestAccountDeletion => '申請刪除帳號';

  @override
  String get accountDeletionRequestDescription => '系統將開啟電子郵件草稿，讓您提交刪除帳號申請。帳號與資料不會立即刪除。';

  @override
  String get continueLabel => '繼續';

  @override
  String get accountDeletionEmailUnavailable => '無法開啟電子郵件程式，請寄信至 minavi@alumni.nccu.edu.tw。';

  @override
  String get requestDataExport => '申請匯出個人資料';

  @override
  String get dataExportRequestDescription => '系統將開啟電子郵件草稿，讓您提交個人資料匯出申請。完成身分核對後，我們會準備匯出資料。';

  @override
  String get dataExportEmailUnavailable => '無法開啟電子郵件程式，請寄信至 minavi@alumni.nccu.edu.tw。';

  @override
  String get agreeToLegalTermsPrefix => '我已閱讀並同意';

  @override
  String get acceptLegalTermsRequired => '請先同意隱私權政策與服務條款，再進行註冊。';

  @override
  String get legalTermsConnector => '與';

  @override
  String get accountMenuDataExport => '資料匯出';

  @override
  String get accountMenuAccountDeletion => '刪除帳號';

  @override
  String get readLegalTermsRequired => '請先閱讀完隱私權政策與服務條款，再勾選同意。';

  @override
  String get legalDocumentReadComplete => '已閱讀完畢';

  @override
  String get legalDocumentRead => '已讀';

  @override
  String get registrationSuccessful => '註冊成功。';

  @override
  String get registrationVerificationRequired => '註冊成功，請前往信箱完成驗證後再登入。';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get passwordMismatch => '兩次輸入的密碼不一致。';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get passwordUpdateSuccessful => '密碼已更新，請使用新密碼登入。';

  @override
  String get stockUpdateInProgress => '股票資料與模型更新中，完成後會自動顯示新結果。';

  @override
  String get stockUpdateSucceeded => '股票資料與模型更新完成。';

  @override
  String get stockUpdateFailed => '股票更新失敗，目前仍顯示上次可用的資料。';

  @override
  String get stockNoData => '目前沒有可顯示的股票資料。';

  @override
  String get stockLoadFailed => '股票資料載入失敗，請稍後再試。';

  @override
  String get stockRetry => '重新載入';
}
