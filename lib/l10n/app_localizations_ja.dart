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
  String get personal_event => '個人のイベント';

  @override
  String get recommended_event => 'おすすめイベント';

  @override
  String get recommended_event_zero => '現在おすすめイベントはありません';

  @override
  String get recommended_attractions => 'おすすめの観光地';

  @override
  String get recommended_attractions_zero => '現在、おすすめのスポットはありません';

  @override
  String get memory_trace => '思い出の回廊';

  @override
  String get memory_trace_zero => 'さあ、思い出を追加しよう！';

  @override
  String get account_records => '収支記録';

  @override
  String get points_record => 'ポイント記録';

  @override
  String get game => 'ゲーム';

  @override
  String get ai => 'AIアシスタント';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';

  @override
  String get search => '検索';

  @override
  String get toggle_view => '表示切り替え';

  @override
  String get export_excel => 'Excelにエクスポート';

  @override
  String get event_add => 'イベントを追加';

  @override
  String get event_add_ok => '✅ イベントを追加しました';

  @override
  String get event_add_error => 'このイベントを繰り返して追加しますか';

  @override
  String get memory_add => '思い出を追加';

  @override
  String get memory_add_ok => '✅ 思い出が追加されました';

  @override
  String get memory_add_error => 'もう一度思い出を追加しますか';

  @override
  String get no_events_to_export => '❌ エクスポートするイベントがありません';

  @override
  String get export_failed => '❌ エクスポート失敗';

  @override
  String get export_success => '✅ エクスポート成功';

  @override
  String get not_support_export => '⚠️ このプラットフォームではエクスポート非対応です';

  @override
  String get excel_column_header_activity_name => 'アクティビティ名_______________________';

  @override
  String get excel_column_header_keywords => 'キーワード_______________________';

  @override
  String get excel_column_header_city => '市区町村';

  @override
  String get excel_column_header_location => '場所____________________';

  @override
  String get excel_column_header_fee => '料金';

  @override
  String get excel_column_header_start_date => '開始日期__';

  @override
  String get excel_column_header_start_time => '開始時間';

  @override
  String get excel_column_header_end_date => '終了日__';

  @override
  String get excel_column_header_end_time => '終了時間';

  @override
  String get excel_column_header_description => '説明______';

  @override
  String get excel_column_header_sponsor => '主催者';

  @override
  String get downloaded => '✅ ダウンロード済み';

  @override
  String get activity_name => 'アクティビティ名';

  @override
  String get keywords => 'キーワード';

  @override
  String get city => '市区町村';

  @override
  String get location => '場所';

  @override
  String get fee => '料金';

  @override
  String get start_date => '開始日期';

  @override
  String get start_time => '開始時間';

  @override
  String get end_date => '終了日';

  @override
  String get end_time => '終了時間';

  @override
  String get description => '説明';

  @override
  String get sponsor => '主催者';

  @override
  String get master_url => 'リンク';

  @override
  String get sub_url => 'リンク';

  @override
  String get event_saved => '✅ イベントを保存しました';

  @override
  String get event_save_error => 'イベント名は空にできません';

  @override
  String get event_add_edit => 'イベントの追加／編集';

  @override
  String get event_add_sub => 'サブ項目を追加';

  @override
  String get event_sub => 'サブイベント';

  @override
  String get save => '保存';

  @override
  String get search_keywords => 'キーワード検索（スペースで区切る）';

  @override
  String get date_clear => '日付をクリア';

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
  String get event_delete => 'イベントを削除';

  @override
  String get delete_ok => '✅ 削除完了';

  @override
  String get delete_error => '❌ 削除失敗';

  @override
  String get click_here_to_see_more => 'もっと見る';

  @override
  String get close => '閉じる';

  @override
  String get url => 'URL';

  @override
  String get speak => '音声入力';

  @override
  String get speak_up => '話してください';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get week_day_sun => '日';

  @override
  String get week_day_mon => '月';

  @override
  String get week_day_tue => '火';

  @override
  String get week_day_wed => '水';

  @override
  String get week_day_thu => '木';

  @override
  String get week_day_fri => '金';

  @override
  String get week_day_sat => '土';

  @override
  String get year => '年';

  @override
  String get month => '月';

  @override
  String get confirm => '確定';

  @override
  String get confirm_delete => '削除しますか';

  @override
  String get set_alarm => 'アラーム設定';

  @override
  String get cancel_alarm => 'アラームキャンセル';

  @override
  String get set_alarm_completed => '✅ アラームを設定しました';

  @override
  String get previous_month => '先月';

  @override
  String get today => '今日';

  @override
  String get next_month => '来月';

  @override
  String get clear => 'クリア';

  @override
  String get repeat_options => '繰り返し回数';

  @override
  String get repeat_options_once => '一度だけ';

  @override
  String get repeat_options_every_day => '毎日';

  @override
  String get repeat_options_every_week => '每週';

  @override
  String get repeat_options_every_two_weeks => '2週間ごと';

  @override
  String get repeat_options_every_month => '每月';

  @override
  String get repeat_options_every_two_months => '2か月ごと';

  @override
  String get repeat_options_every_year => '每年';

  @override
  String get repeat_options_every => '每';

  @override
  String get reminder_options => '通知オプション';

  @override
  String get reminder_options_15_minutes_before => '15分前';

  @override
  String get reminder_options_30_minutes_before => '30分前';

  @override
  String get reminder_options_1_hour_before => '1時間前';

  @override
  String get reminder_options_default_same_day_8am => '当日8時';

  @override
  String get reminder_options_default_day_before_8am => '前日の8時';

  @override
  String get reminder_options_2_days_before => '2日前';

  @override
  String get reminder_options_1_week_before => '1週間前';

  @override
  String get reminder_options_2_weeks_before => '2週間前';

  @override
  String get reminder_options_1_month_before => '1か月前';

  @override
  String get event_reminder => 'イベント通知';

  @override
  String get event_reminder_today => '今日のイベント通知';

  @override
  String get event_reminder_desc => '間もなく開始するイベントをお知らせします';
}
