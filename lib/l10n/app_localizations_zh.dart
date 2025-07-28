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
  String get personal_event => '行事曆';

  @override
  String get recommended_event => '推薦活動';

  @override
  String get recommended_attractions => '推薦景點';

  @override
  String get memory_trace => '回憶走廊';

  @override
  String get account_records => '記帳';

  @override
  String get points_record => '積分';

  @override
  String get game => '遊戲';

  @override
  String get ai => 'AI助理';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';
}
