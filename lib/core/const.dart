import 'package:flutter/widgets.dart';

// -------------------- Auth --------------------
class AuthConstants {
  static const guest = 'Guest';
  static const sysAdminEmail = 'minavi@alumni.nccu.edu.tw';
  static const email = 'email';
  static const password = 'password';
}

// -------------------- Tables --------------------
class TableNames {
  static const calendarEvents = "calendar_events";
  static const recommendedEvents = "recommended_events";
  static const recommendedAttractions = "recommended_attractions";
  static const memoryTrace = "memory_trace";
}

// -------------------- Date Formats --------------------
class DateFormats {
  static const hhmm = 'HH:mm';
  static const mmdd = 'MM/dd';
  static const mmddHHmm = 'MM/dd HH:mm';
  static const yyyyMMddHHmm = 'yyyy/MM/dd HH:mm';
  static const yyyyMMdd = 'yyyy/MM/dd';
}

// -------------------- Calendar Misc --------------------
class CalendarMisc {
  static const zero = '0';
  static const granted = 'granted';
  static const startToS = 'S';
  static const endToE = 'E';
  static const androidIcon = '@mipmap/ic_launcher';
}

const String constEmpty = '';

// -------------------- Gap --------------------
class Gaps {
  // Width
  static const w8 = SizedBox(width: 8);
  static const w16 = SizedBox(width: 16);
  static const w24 = SizedBox(width: 24);
  static const w60 = SizedBox(width: 60);

  // Height
  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h16 = SizedBox(height: 16);
}

// -------------------- Padding / EdgeInsets --------------------
class Insets {
  static const e0 = EdgeInsets.zero;
  static const all1 = EdgeInsets.all(1);
  static const all2 = EdgeInsets.all(2);
  static const all3 = EdgeInsets.all(3);
  static const all4 = EdgeInsets.all(4);
  static const all8 = EdgeInsets.all(8);
  static const all12 = EdgeInsets.all(12);

  static const v4 = EdgeInsets.symmetric(vertical: 4);
  static const h6 = EdgeInsets.symmetric(horizontal: 6);
  static const h8v4 = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
  static const h8v16 = EdgeInsets.symmetric(horizontal: 8, vertical: 16);
  static const h12v8 = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  static const directionalL20T6 = EdgeInsetsDirectional.only(start: 20, top: 6);
  static const directionalL4R4T4B8 = EdgeInsetsDirectional.only(
      start: 4, end: 4, top: 4, bottom: 8);
  static const directionalL1R1B1 = EdgeInsetsDirectional.only(
      start: 1, end: 1, top: 0, bottom: 1);
  static const directionalR3 = EdgeInsetsDirectional.only(end: 3);
}

// -------------------- Message Enum --------------------
enum MSG {
  success, // 成功
  failed, // "失敗"
  notSupportExport, // "⚠️ 此平台尚未支援匯出"
}

// -------------------- Error Fields --------------------
class ErrorFields {
  static const String loginError = 'loginError';
  static const String registerError = 'registerError';
  static const String logoutError = 'logoutError';
  static const String noEmailError = 'noEmailError';
  static const String noPasswordError = 'noPasswordError';
  static const String unexpectedError = 'Unexpected error';

  // 🔹 Firebase Auth 常見錯誤代碼
  static const String authError = 'Auth Error';
  static const String userNotFoundError = 'user-not-found';
  static const String wrongPasswordError = 'wrong-password';
  static const String invalidCredentialError = 'invalid-credential';
  static const String wrongUserPassword = 'wrongUserPassword';
  static const String tooManyRequestsError = 'too-many-requests';
  static const String networkRequestFailedError = 'network-request-failed';
  static const String invalidEmailError = 'invalid-email';
  static const String emailAlreadyInUseError = 'email-already-in-use';
  static const String weakPasswordError = 'weak-password';
  static const String resetPasswordEmailNotFoundError = 'resetPasswordEmailNotFound';
}
