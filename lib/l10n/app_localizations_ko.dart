// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '생활 내비게이션';

  @override
  String get language => '언어';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get login => '  로그인  ';

  @override
  String get loginAnonymously => '게스트 로그인';

  @override
  String get logout => '로그아웃';

  @override
  String get resetPassword => '비밀번호 재설정';

  @override
  String get resetPasswordEmail => '비밀번호 재설정 메일이 전송되었습니다. 메일함을 확인해 주세요.';

  @override
  String get noEmailError => '이메일을 입력해 주세요';

  @override
  String get invalidEmail => '이메일 형식이 올바르지 않습니다';

  @override
  String get noPasswordError => '비밀번호를 입력해 주세요';

  @override
  String get resetPasswordEmailNotFound => '등록되지 않은 이메일입니다';

  @override
  String get wrongUserPassword => '이메일 또는 비밀번호가 잘못되었습니다';

  @override
  String get tooManyRequests => '요청이 너무 많습니다';

  @override
  String get networkError => '네트워크 오류';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get register => '  회원가입  ';

  @override
  String get back => '뒤로';

  @override
  String get loginError => '로그인 실패, 다시 시도해 주세요.';

  @override
  String get logoutError => '로그아웃 실패, 다시 시도해 주세요.';

  @override
  String get registerError => '회원가입 실패, 다시 시도해 주세요.';

  @override
  String get emailAlreadyInUse => '이미 사용 중인 이메일입니다.';

  @override
  String get weakPassword => '비밀번호는 최소 6자 이상이어야 합니다';

  @override
  String get unknownError => '알 수 없는 오류입니다';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '설정';

  @override
  String get personal_event => '개인 일정';

  @override
  String get recommended_event => '추천 이벤트';

  @override
  String get recommended_event_zero => '현재 추천 이벤트가 없습니다';

  @override
  String get recommended_attractions => '추천 명소';

  @override
  String get memory_trace => '추억의 회랑';

  @override
  String get account_records => '가계부 기록';

  @override
  String get points_record => '포인트 기록';

  @override
  String get game => '게임';

  @override
  String get ai => 'AI 도우미';

  @override
  String get pageRecommendedEvent => 'pageRecommendedEvent';

  @override
  String get search => '검색';

  @override
  String get toggle_view => '보기 전환';

  @override
  String get export_excel => 'Excel 내보내기';

  @override
  String get event_add => '이벤트 추가';

  @override
  String get event_add_ok => '✅ 이벤트가 추가되었습니다';

  @override
  String get no_events_to_export => '❌ 내보낼 이벤트가 없습니다';

  @override
  String get export_failed => '❌ 내보내기에 실패했습니다';

  @override
  String get export_success => '✅ 내보내기에 성공했습니다';

  @override
  String get not_support_export => '⚠️ 이 플랫폼은 내보내기를 지원하지 않습니다';

  @override
  String get excel_column_header_activity_name => '활동 이름_______________________';

  @override
  String get excel_column_header_keywords => '키워드_______________________';

  @override
  String get excel_column_header_city => '도시';

  @override
  String get excel_column_header_location => '위치____________________';

  @override
  String get excel_column_header_fee => '요금';

  @override
  String get excel_column_header_start_date => '시작 날짜__';

  @override
  String get excel_column_header_start_time => '시작 시간';

  @override
  String get excel_column_header_end_date => '종료 날짜__';

  @override
  String get excel_column_header_end_time => '종료 시간';

  @override
  String get excel_column_header_description => '설명______';

  @override
  String get excel_column_header_sponsor => '관련 기관';

  @override
  String get downloaded => '✅ 다운로드가 완료되었습니다.';

  @override
  String get activity_name => '이벤트 이름';

  @override
  String get keywords => '키워드';

  @override
  String get city => '도시';

  @override
  String get location => '장소';

  @override
  String get fee => '요금';

  @override
  String get start_date => '시작 날짜';

  @override
  String get start_time => '시작 시간';

  @override
  String get end_date => '종료 날짜';

  @override
  String get end_time => '종료 시간';

  @override
  String get description => '설명';

  @override
  String get sponsor => '관련 기관';

  @override
  String get master_url => '링크';

  @override
  String get sub_url => '링크';

  @override
  String get event_saved => '✅ 이벤트가 저장되었습니다';

  @override
  String get event_save_error => '이벤트 이름은 비울 수 없습니다';

  @override
  String get event_add_edit => '이벤트 추가/편집';

  @override
  String get event_add_sub => '하위 항목 추가';

  @override
  String get event_sub => '하위 이벤트';

  @override
  String get save => '저장';

  @override
  String get search_keywords => '키워드 검색(공백 구분)';

  @override
  String get date_clear => '날짜 초기화';

  @override
  String get event_add_tp_plan_error => '이 이벤트를 반복하여 추가해도 괜찮습니까';

  @override
  String get add => '추가';

  @override
  String get edit => '수정';

  @override
  String get review => '검토';

  @override
  String get cancel => '취소';

  @override
  String get delete => '삭제';

  @override
  String get event_delete => '이벤트 삭제';

  @override
  String get delete_ok => '✅ 삭제 완료';

  @override
  String get delete_error => '❌ 삭제 실패';

  @override
  String get click_here_to_see_more => '더 보기 클릭';

  @override
  String get close => '닫기';

  @override
  String get url => 'URL';

  @override
  String get speak => '음성 입력';

  @override
  String get speak_up => '말해 주세요';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get week_day_sun => '일';

  @override
  String get week_day_mon => '월';

  @override
  String get week_day_tue => '화';

  @override
  String get week_day_wed => '수';

  @override
  String get week_day_thu => '목';

  @override
  String get week_day_fri => '금';

  @override
  String get week_day_sat => '토';

  @override
  String get year => '년';

  @override
  String get month => '월';

  @override
  String get confirm => '확인';

  @override
  String get confirm_delete => '정말 삭제하시겠습니까?';

  @override
  String get set_alarm => '알람 설정';

  @override
  String get cancel_alarm => '알람 취소';

  @override
  String get set_alarm_completed => '✅ 알람이 설정되었습니다';

  @override
  String get previous_month => '이전 달';

  @override
  String get today => '오늘';

  @override
  String get next_month => '다음 달';

  @override
  String get clear => '초기화';

  @override
  String get repeat_options => '반복 횟수';

  @override
  String get repeat_options_once => '한 번';

  @override
  String get repeat_options_every_day => '매일';

  @override
  String get repeat_options_every_week => '매주';

  @override
  String get repeat_options_every_two_weeks => '2주마다';

  @override
  String get repeat_options_every_month => '매월';

  @override
  String get repeat_options_every_two_months => '2개월마다';

  @override
  String get repeat_options_every_year => '매년';

  @override
  String get repeat_options_every => '매';

  @override
  String get reminder_options => '알림 시간';

  @override
  String get reminder_options_15_minutes_before => '15분 전';

  @override
  String get reminder_options_30_minutes_before => '30분 전';

  @override
  String get reminder_options_1_hour_before => '1시간 전';

  @override
  String get reminder_options_default_same_day_8am => '당일 오전 8시';

  @override
  String get reminder_options_default_day_before_8am => '전날 오전 8시';

  @override
  String get reminder_options_2_days_before => '2일 전';

  @override
  String get reminder_options_1_week_before => '1주 전';

  @override
  String get reminder_options_2_weeks_before => '2주 전';

  @override
  String get reminder_options_1_month_before => '1개월 전';

  @override
  String get event_reminder => '이벤트 알림';

  @override
  String get event_reminder_today => '오늘의 이벤트 알림';

  @override
  String get event_reminder_desc => '곧 시작될 이벤트를 알려드립니다';
}
