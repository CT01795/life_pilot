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
  String resetPasswordCooldown(int seconds) {
    return '$seconds초 후 재전송 가능';
  }

  @override
  String get noEmailError => '이메일을 입력해 주세요';

  @override
  String get invalidEmail => '이메일 형식이 올바르지 않습니다';

  @override
  String get noPasswordError => '비밀번호를 입력해 주세요';

  @override
  String get noRecoverySession => '시스템이 유효한 [확인 자격 증명] 을 찾을 수 없거나, 해당 자격 증명이 만료되었습니다.';

  @override
  String get resetPasswordError => '비밀번호 재설정에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get resetPasswordEmailNotFound => '등록되지 않은 이메일입니다';

  @override
  String get wrongUserPassword => '이메일 또는 비밀번호가 잘못되었습니다';

  @override
  String get emailNotConfirmed => '이메일이 확인되지 않았습니다';

  @override
  String get tooManyRequests => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get emailRateLimitExceeded => '인증 이메일 전송 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get networkError => '연결할 수 없습니다. 네트워크를 확인한 후 다시 시도해 주세요.';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get register => '  회원가입  ';

  @override
  String get updatePassword => '비밀번호 변경';

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
  String get weakPassword => '비밀번호는 8자 이상이어야 합니다.';

  @override
  String get unknownError => '알 수 없는 오류입니다';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '설정';

  @override
  String get pageSelectorTooltip => '기능 메뉴';

  @override
  String get userMenuButton => '사용자 메뉴';

  @override
  String get home => '홈';

  @override
  String get completeEventTitle => '여행 일정을 완성하세요';

  @override
  String get completeEventMessage => '이 여정이 완료되면 오늘의 목록에서 사라집니다.';

  @override
  String get noInfoAvailable => '이용 가능한 정보가 없습니다.';

  @override
  String get openMap => '내비게이션';

  @override
  String get selectCity => '도시 선택';

  @override
  String get selectAccount => '계정 선택';

  @override
  String get personalEvent => '개인 일정';

  @override
  String get stock => '재고';

  @override
  String get recommendEvent => '추천 이벤트';

  @override
  String get recommendEventZero => '현재 추천 이벤트가 없습니다';

  @override
  String get recommendPlaces => '추천 명소';

  @override
  String get recommendPlacesZero => '현재 추천할 장소가 없습니다';

  @override
  String get memoryTrace => '추억의 회랑';

  @override
  String get memoryTraceZero => '어서 추억을 추가해봐요!';

  @override
  String get accountPersonal => '개인의';

  @override
  String get accountProject => '여행';

  @override
  String get accountMaster => '그룹';

  @override
  String get accountRecords => '가계부 기록';

  @override
  String get todayIncomeExpense => '오늘의 수입과 지출';

  @override
  String get todayPoints => '오늘의 핵심 포인트';

  @override
  String get pointsRecord => '포인트 기록';

  @override
  String get game => '게임';

  @override
  String get gameStart => '시작';

  @override
  String get gameNoRecords => '게임 기록이 없습니다';

  @override
  String get gameLevel => '레벨';

  @override
  String get gameScore => '점수';

  @override
  String get ai => 'AI 도우미';

  @override
  String get feedback => '피드백';

  @override
  String get businessPlan => 'Business Plan';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get search => '검색';

  @override
  String get toggleView => '보기 전환';

  @override
  String get exportExcel => 'Excel 내보내기';

  @override
  String get eventAdd => '이벤트 추가';

  @override
  String get eventAdd1 => '캘린더에 새 이벤트 추가';

  @override
  String get eventAddOk => '✅ 이벤트가 추가되었습니다';

  @override
  String get eventAddError => '이 이벤트를 반복하여 추가해도 괜찮습니까';

  @override
  String get memoryAdd => '추억 추가';

  @override
  String get memoryAddOk => '✅ 추억이 추가되었습니다';

  @override
  String get memoryAddError => '추억을 다시 추가하시겠습니까';

  @override
  String get uploadExcel => 'Csv 업로드';

  @override
  String get uploadFailed => '❌ 업로드 실패';

  @override
  String get uploadInProgress => '❌ 이전 파일 업로드가 아직 진행 중입니다.';

  @override
  String get uploadSuccess => '✅ 업로드 성공';

  @override
  String get notSupportUpload => '⚠️ 업로드를 지원하지 않음';

  @override
  String get noEventsToUpload => '❌ 업로드할 이벤트가 없습니다.';

  @override
  String get noEventsToExport => '❌ 내보낼 이벤트가 없습니다';

  @override
  String get exportFailed => '❌ 내보내기에 실패했습니다';

  @override
  String get exportInProgress => '❌ 이전 파일 내보내기가 아직 진행 중입니다.';

  @override
  String get exportSuccess => '✅ 내보내기에 성공했습니다';

  @override
  String get notSupportExport => '⚠️ 이 플랫폼은 내보내기를 지원하지 않습니다';

  @override
  String get excelColumnHeaderId => '활동 id_______________________';

  @override
  String get excelColumnHeaderMasterUrl => '활동 url_______________________';

  @override
  String get excelColumnHeaderActivityName => '활동 이름_______________________';

  @override
  String get excelColumnHeaderKeywords => '키워드_______________________';

  @override
  String get excelColumnHeaderCity => '도시';

  @override
  String get excelColumnHeaderLocation => '위치____________________';

  @override
  String get excelColumnHeaderFee => '요금';

  @override
  String get excelColumnHeaderStartDate => '시작 날짜__';

  @override
  String get excelColumnHeaderStartTime => '시작 시간';

  @override
  String get excelColumnHeaderEndDate => '종료 날짜__';

  @override
  String get excelColumnHeaderEndTime => '종료 시간';

  @override
  String get excelColumnHeaderDescription => '설명______';

  @override
  String get excelColumnHeaderSponsor => '관련 기관';

  @override
  String get excelColumnHeaderAgeMin => '최소 연령';

  @override
  String get excelColumnHeaderAgeMax => '최대 연령';

  @override
  String get excelColumnHeaderIsFree => '무료 ?';

  @override
  String get excelColumnHeaderPriceMin => '최소 가격';

  @override
  String get excelColumnHeaderPriceMax => '최대 가격';

  @override
  String get excelColumnHeaderIsOutdoor => '옥외 ?';

  @override
  String get downloaded => '✅ 다운로드가 완료되었습니다.';

  @override
  String get activityName => '이벤트 이름';

  @override
  String get keywords => '키워드';

  @override
  String get city => '도시';

  @override
  String get location => '장소';

  @override
  String get fee => '요금';

  @override
  String get startDate => '시작 날짜';

  @override
  String get startTime => '시작 시간';

  @override
  String get endDate => '종료 날짜';

  @override
  String get endTime => '종료 시간';

  @override
  String get description => '설명';

  @override
  String get sponsor => '관련 기관';

  @override
  String get ageMin => '최소 연령';

  @override
  String get ageMax => '최대 연령';

  @override
  String get priceMin => '최소 가격';

  @override
  String get priceMax => '최대 가격';

  @override
  String get isFree => '무료 ?';

  @override
  String get isOutdoor => '옥외 ?';

  @override
  String get toBeDetermined => '미정';

  @override
  String get free => '무료';

  @override
  String get pay => '지불하다';

  @override
  String get outdoor => '옥외';

  @override
  String get indoor => '실내';

  @override
  String get masterUrl => '링크';

  @override
  String get subUrl => '링크';

  @override
  String get eventSaved => '✅ 이벤트가 저장되었습니다';

  @override
  String get eventSaveError => '이벤트 이름은 비울 수 없습니다';

  @override
  String get eventAlreadyExists => '이미 존재하는 이벤트입니다';

  @override
  String get eventSaveFailed => '이벤트를 저장하지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get dashboardLoadFailed => '정보를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get retry => '다시 시도';

  @override
  String get externalLinkOpenFailed => '링크를 열 수 없습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get dashboardSettingSaveFailed => '설정을 저장하지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get accountListLoadFailed => '계정 목록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get accountListEmpty => '아직 계정이 없습니다. 계정을 만든 후 선택해 주세요.';

  @override
  String get unsavedChangesPrompt => '변경 사항이 저장되지 않았습니다. 취소하시겠습니까?';

  @override
  String get discardChanges => '변경 사항 취소';

  @override
  String get eventAddEdit => '이벤트 추가/편집';

  @override
  String get eventAddSub => '하위 항목 추가';

  @override
  String get eventSub => '하위 이벤트';

  @override
  String get save => '저장';

  @override
  String get searchKeywords => '키워드 검색(쉼표로 구분됨)';

  @override
  String get dateClear => '날짜 초기화';

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
  String get like => '좋다';

  @override
  String get dislike => '싫어함';

  @override
  String get eventDelete => '이벤트 삭제';

  @override
  String get deleteOk => '✅ 삭제 완료';

  @override
  String get deleteError => '삭제 실패';

  @override
  String get todaySchedule => '오늘의 일정';

  @override
  String get upcomingSchedule => '향후 일정';

  @override
  String get addToSchedule => '일정에 추가';

  @override
  String get clickHereToSeeMore => '더 보기 클릭';

  @override
  String get close => '닫기';

  @override
  String get url => 'URL';

  @override
  String get speak => '음성 입력';

  @override
  String get speakUp => '말해 주세요';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get weekDaySun => '일';

  @override
  String get weekDayMon => '월';

  @override
  String get weekDayTue => '화';

  @override
  String get weekDayWed => '수';

  @override
  String get weekDayThu => '목';

  @override
  String get weekDayFri => '금';

  @override
  String get weekDaySat => '토';

  @override
  String get year => '년';

  @override
  String get month => '월';

  @override
  String get confirm => '확인';

  @override
  String get confirmDelete => '정말 삭제하시겠습니까?';

  @override
  String get setAlarm => '알람 설정';

  @override
  String get cancelAlarm => '알람 취소';

  @override
  String get setAlarmCompleted => '✅ 알람이 설정되었습니다';

  @override
  String get alarmUpdateFailed => '알림을 설정하지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get previousMonth => '이전 달';

  @override
  String get today => '오늘';

  @override
  String get nextMonth => '다음 달';

  @override
  String get postText => '전문을 게시하세요';

  @override
  String get parsing => '분석하다';

  @override
  String get clear => '초기화';

  @override
  String get repeatOptions => '반복 횟수';

  @override
  String get repeatOptionsOnce => '한 번';

  @override
  String get repeatOptionsEveryDay => '매일';

  @override
  String get repeatOptionsEveryWeek => '매주';

  @override
  String get repeatOptionsEveryTwoWeeks => '2주마다';

  @override
  String get repeatOptionsEveryMonth => '매월';

  @override
  String get repeatOptionsEveryTwoMonths => '2개월마다';

  @override
  String get repeatOptionsEveryYear => '매년';

  @override
  String get repeatOptionsEvery => '매';

  @override
  String get reminderOptions => '알림 시간';

  @override
  String get reminderOptions15MinutesBefore => '15분 전';

  @override
  String get reminderOptions30MinutesBefore => '30분 전';

  @override
  String get reminderOptionsOneHourBefore => '1시간 전';

  @override
  String get reminderOptionsDefaultSameDay8am => '당일 오전 8시';

  @override
  String get reminderOptionsDefaultDayBefore8am => '전날 오전 8시';

  @override
  String get reminderOptionsTwoDaysBefore => '2일 전';

  @override
  String get reminderOptionsOneWeekBefore => '1주 전';

  @override
  String get reminderOptionsTwoWeeksBefore => '2주 전';

  @override
  String get reminderOptionsOneMonthBefore => '1개월 전';

  @override
  String get eventReminder => '이벤트 알림';

  @override
  String get eventReminderToday => '오늘의 이벤트 알림';

  @override
  String get eventReminderDesc => '곧 시작될 이벤트를 알려드립니다';

  @override
  String get privacyPolicy => '개인정보 처리방침';

  @override
  String get termsOfService => '서비스 약관';

  @override
  String get requestAccountDeletion => '계정 삭제 요청';

  @override
  String get accountDeletionRequestDescription => '계정 삭제 요청을 위한 이메일 초안을 엽니다. 계정과 데이터는 즉시 삭제되지 않습니다.';

  @override
  String get continueLabel => '계속';

  @override
  String get accountDeletionEmailUnavailable => '이메일 앱을 열 수 없습니다. minavi@alumni.nccu.edu.tw로 문의해 주세요.';

  @override
  String get requestDataExport => '개인 데이터 내보내기 요청';

  @override
  String get dataExportRequestDescription => '개인 데이터 내보내기 요청을 위한 이메일 초안을 엽니다. 본인 확인 후 데이터를 준비합니다.';

  @override
  String get dataExportEmailUnavailable => '이메일 앱을 열 수 없습니다. minavi@alumni.nccu.edu.tw로 문의해 주세요.';

  @override
  String get agreeToLegalTermsPrefix => '다음을 읽고 동의합니다: ';

  @override
  String get acceptLegalTermsRequired => '등록하기 전에 개인정보 처리방침 및 서비스 약관에 동의해 주세요.';

  @override
  String get legalTermsConnector => ' 및 ';

  @override
  String get accountMenuDataExport => '데이터 내보내기';

  @override
  String get accountMenuAccountDeletion => '계정 삭제';

  @override
  String get readLegalTermsRequired => '동의하기 전에 개인정보 처리방침과 서비스 약관을 끝까지 읽어 주세요.';

  @override
  String get legalDocumentReadComplete => '읽기를 완료했습니다';

  @override
  String get legalDocumentRead => '읽음';

  @override
  String get registrationSuccessful => '가입이 완료되었습니다.';

  @override
  String get registrationVerificationRequired => '가입이 완료되었습니다. 이메일 인증 후 로그인해 주세요.';

  @override
  String get confirmPassword => '비밀번호 확인';

  @override
  String get passwordMismatch => '비밀번호가 일치하지 않습니다.';

  @override
  String get showPassword => '비밀번호 표시';

  @override
  String get hidePassword => '비밀번호 숨기기';

  @override
  String get passwordUpdateSuccessful => '비밀번호가 변경되었습니다. 새 비밀번호로 로그인해 주세요.';

  @override
  String get stockUpdateInProgress => '주식 데이터와 모델을 업데이트하고 있습니다. 완료되면 새 결과가 자동으로 표시됩니다.';

  @override
  String get stockUpdateSucceeded => '주식 데이터와 모델 업데이트가 완료되었습니다.';

  @override
  String get stockUpdateFailed => '주식 업데이트에 실패했습니다. 마지막으로 사용 가능한 데이터를 계속 표시합니다.';

  @override
  String get stockNoData => '현재 표시할 수 있는 주식 데이터가 없습니다.';

  @override
  String get stockLoadFailed => '주식 데이터를 불러오지 못했습니다. 다시 시도해 주세요.';

  @override
  String get stockRetry => '다시 불러오기';
}
