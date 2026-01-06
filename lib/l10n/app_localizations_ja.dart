// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '生活ナビゲーション';

  @override
  String get language => '言語';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get login => '  ログイン  ';

  @override
  String get loginAnonymously => 'ゲストログイン';

  @override
  String get logout => 'ログアウト';

  @override
  String get resetPassword => 'パスワード再設定';

  @override
  String get resetPasswordEmail => 'パスワード再設定メールを送信しました。メールを確認してください。';

  @override
  String get noEmailError => 'メールアドレスを入力してください';

  @override
  String get invalidEmail => 'メールアドレスの形式が正しくありません';

  @override
  String get noPasswordError => 'パスワードを入力してください';

  @override
  String get resetPasswordEmailNotFound => '登録されていないメールアドレスです';

  @override
  String get wrongUserPassword => 'メールかパスワードが正しくありません';

  @override
  String get tooManyRequests => 'リクエストが多すぎます';

  @override
  String get networkError => 'ネットワークエラー';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get register => '  登録  ';

  @override
  String get back => '戻る';

  @override
  String get loginError => 'ログイン失敗、もう一度お試しください。';

  @override
  String get logoutError => 'ログアウト失敗、もう一度お試しください。';

  @override
  String get registerError => '登録に失敗しました。もう一度お試しください。';

  @override
  String get emailAlreadyInUse => 'このメールアドレスは既に登録されています。';

  @override
  String get weakPassword => 'パスワードは少なくとも6文字必要です';

  @override
  String get unknownError => '不明なエラーです';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '設定';

  @override
  String get personalEvent => '個人のイベント';

  @override
  String get recommendedEvent => 'おすすめイベント';

  @override
  String get recommendedEventZero => '現在おすすめイベントはありません';

  @override
  String get recommendedAttractions => 'おすすめの観光地';

  @override
  String get recommendedAttractionsZero => '現在、おすすめのスポットはありません';

  @override
  String get memoryTrace => '思い出の回廊';

  @override
  String get memoryTraceZero => 'さあ、思い出を追加しよう！';

  @override
  String get accountRecords => '収支記録';

  @override
  String get pointsRecord => 'ポイント記録';

  @override
  String get game => 'ゲーム';

  @override
  String get ai => 'AIアシスタント';

  @override
  String get feedback => 'Feedback';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';

  @override
  String get search => '検索';

  @override
  String get toggleView => '表示切り替え';

  @override
  String get exportExcel => 'Excelにエクスポート';

  @override
  String get eventAdd => 'イベントを追加';

  @override
  String get eventAddOk => '✅ イベントを追加しました';

  @override
  String get eventAddError => 'このイベントを繰り返して追加しますか';

  @override
  String get memoryAdd => '思い出を追加';

  @override
  String get memoryAddOk => '✅ 思い出が追加されました';

  @override
  String get memoryAddError => 'もう一度思い出を追加しますか';

  @override
  String get noEventsToExport => '❌ エクスポートするイベントがありません';

  @override
  String get exportFailed => '❌ エクスポート失敗';

  @override
  String get exportInProgress => '❌ 以前のファイルのエクスポートはまだ進行中です。';

  @override
  String get exportSuccess => '✅ エクスポート成功';

  @override
  String get notSupportExport => '⚠️ このプラットフォームではエクスポート非対応です';

  @override
  String get excelColumnHeaderActivityName => 'アクティビティ名_______________________';

  @override
  String get excelColumnHeaderKeywords => 'キーワード_______________________';

  @override
  String get excelColumnHeaderCity => '市区町村';

  @override
  String get excelColumnHeaderLocation => '場所____________________';

  @override
  String get excelColumnHeaderFee => '料金';

  @override
  String get excelColumnHeaderStartDate => '開始日期__';

  @override
  String get excelColumnHeaderStartTime => '開始時間';

  @override
  String get excelColumnHeaderEndDate => '終了日__';

  @override
  String get excelColumnHeaderEndTime => '終了時間';

  @override
  String get excelColumnHeaderDescription => '説明______';

  @override
  String get excelColumnHeaderSponsor => '主催者';

  @override
  String get downloaded => '✅ ダウンロード済み';

  @override
  String get activityName => 'アクティビティ名';

  @override
  String get keywords => 'キーワード';

  @override
  String get city => '市区町村';

  @override
  String get location => '場所';

  @override
  String get fee => '料金';

  @override
  String get startDate => '開始日期';

  @override
  String get startTime => '開始時間';

  @override
  String get endDate => '終了日';

  @override
  String get endTime => '終了時間';

  @override
  String get description => '説明';

  @override
  String get sponsor => '主催者';

  @override
  String get masterUrl => 'リンク';

  @override
  String get subUrl => 'リンク';

  @override
  String get eventSaved => '✅ イベントを保存しました';

  @override
  String get eventSaveError => 'イベント名は空にできません';

  @override
  String get eventAddEdit => 'イベントの追加／編集';

  @override
  String get eventAddSub => 'サブ項目を追加';

  @override
  String get eventSub => 'サブイベント';

  @override
  String get save => '保存';

  @override
  String get searchKeywords => 'キーワード検索（スペースで区切る）';

  @override
  String get dateClear => '日付をクリア';

  @override
  String get add => '追加';

  @override
  String get edit => '編集';

  @override
  String get review => 'レビュー';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get eventDelete => 'イベントを削除';

  @override
  String get deleteOk => '✅ 削除完了';

  @override
  String get deleteError => '❌ 削除失敗';

  @override
  String get clickHereToSeeMore => 'もっと見る';

  @override
  String get close => '閉じる';

  @override
  String get url => 'URL';

  @override
  String get speak => '音声入力';

  @override
  String get speakUp => '話してください';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get weekDaySun => '日';

  @override
  String get weekDayMon => '月';

  @override
  String get weekDayTue => '火';

  @override
  String get weekDayWed => '水';

  @override
  String get weekDayThu => '木';

  @override
  String get weekDayFri => '金';

  @override
  String get weekDaySat => '土';

  @override
  String get year => '年';

  @override
  String get month => '月';

  @override
  String get confirm => '確定';

  @override
  String get confirmDelete => '削除しますか';

  @override
  String get setAlarm => 'アラーム設定';

  @override
  String get cancelAlarm => 'アラームキャンセル';

  @override
  String get setAlarmCompleted => '✅ アラームを設定しました';

  @override
  String get previousMonth => '先月';

  @override
  String get today => '今日';

  @override
  String get nextMonth => '来月';

  @override
  String get clear => 'クリア';

  @override
  String get repeatOptions => '繰り返し回数';

  @override
  String get repeatOptionsOnce => '一度だけ';

  @override
  String get repeatOptionsEveryDay => '毎日';

  @override
  String get repeatOptionsEveryWeek => '每週';

  @override
  String get repeatOptionsEveryTwoWeeks => 'Every two weeks';

  @override
  String get repeatOptionsEveryMonth => '每月';

  @override
  String get repeatOptionsEveryTwoMonths => '2か月ごと';

  @override
  String get repeatOptionsEveryYear => '每年';

  @override
  String get repeatOptionsEvery => '每';

  @override
  String get reminderOptions => '通知オプション';

  @override
  String get reminderOptions15MinutesBefore => '15分前';

  @override
  String get reminderOptions30MinutesBefore => '30分前';

  @override
  String get reminderOptionsOneHourBefore => '1時間前';

  @override
  String get reminderOptionsDefaultSameDay8am => '当日8時';

  @override
  String get reminderOptionsDefaultDayBefore8am => '前日の8時';

  @override
  String get reminderOptionsTwoDaysBefore => '2日前';

  @override
  String get reminderOptionsOneWeekBefore => '1週間前';

  @override
  String get reminderOptionsTwoWeeksBefore => '2週間前';

  @override
  String get reminderOptionsOneMonthBefore => '1か月前';

  @override
  String get eventReminder => 'イベント通知';

  @override
  String get eventReminderToday => '今日のイベント通知';

  @override
  String get eventReminderDesc => '間もなく開始するイベントをお知らせします';
}
