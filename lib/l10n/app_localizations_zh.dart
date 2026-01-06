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
  String get noEmailError => '請輸入帳號';

  @override
  String get invalidEmail => '帳號格式錯誤';

  @override
  String get noPasswordError => '請輸入密碼';

  @override
  String get resetPasswordEmailNotFound => '帳號未註冊';

  @override
  String get wrongUserPassword => '帳號密碼錯誤';

  @override
  String get tooManyRequests => '登入過於頻繁';

  @override
  String get networkError => '網路錯誤';

  @override
  String get email => '電子郵件';

  @override
  String get password => '密碼';

  @override
  String get register => '  註冊  ';

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
  String get weakPassword => '密碼長度必須至少為 6 個字元';

  @override
  String get unknownError => '未知的錯誤';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '設定';

  @override
  String get personalEvent => '行事曆';

  @override
  String get recommendedEvent => '推薦活動';

  @override
  String get recommendedEventZero => '目前沒有推薦活動';

  @override
  String get recommendedAttractions => '推薦景點';

  @override
  String get recommendedAttractionsZero => '目前沒有推薦景點';

  @override
  String get memoryTrace => '回憶走廊';

  @override
  String get memoryTraceZero => '去創造更多回憶吧！';

  @override
  String get accountRecords => '記帳';

  @override
  String get pointsRecord => '積分';

  @override
  String get game => '遊戲';

  @override
  String get ai => 'AI助理';

  @override
  String get feedback => 'Feedback';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';

  @override
  String get search => '搜尋';

  @override
  String get toggleView => '切換檢視模式';

  @override
  String get exportExcel => '匯出 Excel';

  @override
  String get eventAdd => '新增活動';

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
  String get masterUrl => '連結';

  @override
  String get subUrl => '連結';

  @override
  String get eventSaved => '✅ 活動已儲存';

  @override
  String get eventSaveError => '活動名稱不可為空';

  @override
  String get eventAddEdit => '新增／編輯活動';

  @override
  String get eventAddSub => '新增細項';

  @override
  String get eventSub => '細項活動';

  @override
  String get save => '儲存';

  @override
  String get searchKeywords => '關鍵字搜尋(空白分隔)';

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
  String get eventDelete => '刪除活動';

  @override
  String get deleteOk => '✅ 刪除完成';

  @override
  String get deleteError => '❌ 刪除失敗';

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
  String get previousMonth => '上一個月';

  @override
  String get today => '今日';

  @override
  String get nextMonth => '下一個月';

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
  String get repeatOptionsEveryYear => 'Every year';

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
}
