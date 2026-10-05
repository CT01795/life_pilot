// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get vendorSubmissionTitle => '등록 센터';

  @override
  String get vendorSubmissionDescription => '일정을 계획하는 사용자에게 행사와 명소를 알리고, 공개 후에도 작성자가 관리할 수 있습니다.';

  @override
  String get vendorSubmissionBenefitReach => '계획 중인 사용자에게 노출';

  @override
  String get vendorSubmissionBenefitManage => '정보 직접 관리';

  @override
  String get vendorSubmissionBenefitReview => '명확한 심사 상태';

  @override
  String get vendorSubmitActivity => '행사 등록';

  @override
  String get vendorSubmitAttraction => '명소 등록';

  @override
  String get vendorMySubmissions => '내 등록';

  @override
  String get vendorAllActivities => '전체 등록';

  @override
  String get vendorSubmitShort => '등록';

  @override
  String get vendorMineShort => '내 것';

  @override
  String get vendorAllShort => '전체';

  @override
  String get vendorSubmissionGuideTitle => '더 많은 사람이 행사를 발견하게 하세요';

  @override
  String get vendorAttractionSubmissionGuideTitle => '더 많은 사람에게 명소 알리기';

  @override
  String get attractionAddEdit => '명소 추가/수정';

  @override
  String get vendorSubmissionGuideDescription => '정확한 날짜, 장소, 주최자, 신청 URL을 입력하세요. 심사 후 공개되며 수정하면 다시 심사를 받습니다.';

  @override
  String get vendorCreateAccountTitle => '행사 주최자인가요?';

  @override
  String get vendorCreateAccountDescription => '계정을 만들어 행사를 등록하고 심사 상태를 확인하며 공개 정보를 계속 관리하세요.';

  @override
  String get vendorCreateAccountAction => '계정 만들고 등록';

  @override
  String get vendorRegistrationTitle => '주최자 계정';

  @override
  String get vendorRegistrationDescription => '행사, 명소 및 심사 상태를 관리하는 주최자 작업 공간을 사용합니다.';

  @override
  String get vendorDashboardTitle => '주최자 작업 공간';

  @override
  String get vendorDashboardSubtitle => '등록 자료와 심사 상태를 관리하고 현재 한도를 확인하세요.';

  @override
  String get vendorDashboardLoadFailed => '주최자 정보를 불러오지 못했.uc2b5니다.';

  @override
  String get vendorActiveActivities => '활성 행사';

  @override
  String get vendorActiveAttractions => '활성 명소';

  @override
  String vendorCurrentPlan(String plan) {
    return '현재 요금제: $plan';
  }

  @override
  String get vendorManageActivities => '행사 관리';

  @override
  String get vendorManageAttractions => '명소 관리';

  @override
  String get vendorPricingTitle => '주최자 요금제';

  @override
  String get vendorPricingDescription => '무료로 시작하고 필요에 따라 공개 자료 수와 분석 기간을 늘릴 수 있습니다.';

  @override
  String get vendorPricingActiveOnlyNote => '한도는 아직 종료되지 않은 자료만 계산합니다. 종료된 자료는 활성 게시 한도를 사용하지 않습니다.';

  @override
  String vendorQuarterlyPrice(int price) {
    return '분기 NT\$$price';
  }

  @override
  String vendorPlanActivityQuota(int count) {
    return '활성 행사 최대 $count개';
  }

  @override
  String vendorPlanAttractionQuota(int count) {
    return '활성 명소 최대 $count개';
  }

  @override
  String vendorPlanImageQuota(int count) {
    return '이미지 용량 $count MB';
  }

  @override
  String vendorPlanAnalyticsDays(int count) {
    return '최근 $count일 분석';
  }

  @override
  String get vendorContentQuotaReached => '활성 게시 한도가 찼습니다. 진행 중인 자료를 삭제하거나 주최자 요금제를 업그레이드하세요.';

  @override
  String get vendorImageQuotaReached => '주최자 이미지 한도가 찼습니다. 이미지를 삭제하거나 주최자 요금제를 업그레이드하세요.';

  @override
  String get vendorAnalyticsDays => '분석 일수';

  @override
  String get vendorPlanFreeName => '무료 요금제';

  @override
  String get vendorPlanPartnerName => '파트너 요금제';

  @override
  String get vendorPlanGrowthName => '성장 요금제';

  @override
  String get vendorPlanCustomName => '맞춤 요금제';

  @override
  String get vendorAnalyticsTitle => '성과 분석';

  @override
  String vendorAnalyticsDescription(int days) {
    return '최근 $days일 동안 활동 및 명소와의 상호작용입니다.';
  }

  @override
  String vendorPendingReviewCount(int count) {
    return '검토 대기 중인 등록 $count건';
  }

  @override
  String get vendorPendingReviewHint => '검토 상태를 여기에서 확인할 수 있으며 승인 후 모든 사용자에게 공개됩니다.';

  @override
  String vendorQuotaRemaining(int count, String suffix) {
    return '남은 한도 $count$suffix';
  }

  @override
  String get vendorClickThroughRate => '조회 대비 클릭';

  @override
  String get vendorRegistrationRate => '클릭 대비 신청';

  @override
  String vendorPositiveActions(int count) {
    return '저장 및 좋아요 $count회';
  }

  @override
  String get vendorNextStepFirstTitle => '첫 콘텐츠를 등록하세요';

  @override
  String get vendorNextStepFirstMessage => '정확한 날짜, 장소, 이미지와 신청 링크가 있는 행사부터 시작하세요.';

  @override
  String get vendorNextStepReviewTitle => '등록 내용을 검토 중입니다';

  @override
  String get vendorNextStepReviewMessage => '여기에서 결과를 확인할 수 있으며 승인되면 일정을 계획하는 모든 사용자에게 공개됩니다.';

  @override
  String get vendorNextStepExposureTitle => '분명한 첫인상을 만드세요';

  @override
  String get vendorNextStepExposureMessage => '명확한 이름, 대표 이미지와 도시 정보는 콘텐츠를 더 쉽게 찾고 이해하게 합니다.';

  @override
  String get vendorNextStepClickTitle => '조회를 관심으로 바꾸세요';

  @override
  String get vendorNextStepClickMessage => '소개 문구, 주요 특징과 이미지를 보완해 클릭할 이유를 알려 주세요.';

  @override
  String get vendorNextStepRegistrationTitle => '신청을 더 쉽게 만드세요';

  @override
  String get vendorNextStepRegistrationMessage => '신청 URL이 유효하고 신청 방법과 안내가 명확한지 확인하세요.';

  @override
  String get vendorNextStepGrowingTitle => '콘텐츠가 행동을 만들고 있습니다';

  @override
  String get vendorNextStepGrowingMessage => '날짜와 이용 가능 정보를 최신으로 유지하고 전환율을 다음 등록 개선에 활용하세요.';

  @override
  String get vendorAnalyticsPageViews => '페이지 조회';

  @override
  String get vendorAnalyticsCardClicks => '콘텐츠 클릭';

  @override
  String get vendorAnalyticsRegistrationClicks => '신청 클릭';

  @override
  String get vendorAnalyticsSaves => '저장';

  @override
  String get vendorAnalyticsLikes => '좋아요';

  @override
  String get vendorAnalyticsDislikes => '싫어요';

  @override
  String vendorQualityProgress(int count, int total) {
    return '게시물 완성도: $count/$total';
  }

  @override
  String get vendorQualityName => '제목';

  @override
  String get vendorQualityDate => '날짜';

  @override
  String get vendorQualityCity => '도시';

  @override
  String get vendorQualityLocation => '장소';

  @override
  String get vendorQualityDescription => '설명';

  @override
  String get vendorQualityLink => '신청 링크';

  @override
  String get vendorContentMixTitle => '콘텐츠 현황';

  @override
  String vendorActivityAttractionMix(int activities, int attractions) {
    return '진행 중인 행사 $activities개 · 명소 $attractions개';
  }

  @override
  String vendorPublishedPendingMix(int published, int pending) {
    return '공개 $published개 · 검토 대기 $pending개';
  }

  @override
  String get vendorRecentSubmissionsTitle => '최근 게시물';

  @override
  String get vendorRecentSubmissionsEmpty => '아직 게시물이 없습니다. 첫 행사나 명소를 추가하세요.';

  @override
  String get vendorActivityLabel => '행사';

  @override
  String get vendorAttractionLabel => '명소';

  @override
  String get vendorUntitledSubmission => '제목 없는 게시물';

  @override
  String get vendorQuotaFullHint => '한도가 가득 찼습니다. 업그레이드하거나 진행 중인 게시물을 삭제하세요.';

  @override
  String get vendorQuotaNearFullHint => '한도가 거의 찼습니다. 다음 게시물 전에 요금제를 확인하세요.';

  @override
  String get vendorViewPlans => '요금제 보기';

  @override
  String get vendorAnalyticsEmpty => '공개 콘텐츠에 조회와 반응이 생기면 여기에 성과가 표시됩니다.';

  @override
  String get vendorRegistrationFreeStart => '무료 주최자 요금제로 시작';

  @override
  String get vendorRegistrationAnalytics => '한 작업 공간에서 콘텐츠 성과 확인';

  @override
  String get publishedContentDeleteAdminOnly => '공개된 정보는 관리자만 삭제할 수 있습니다. 수정 후 저장하면 검토 대기 상태로 돌아갑니다.';

  @override
  String get adminVendorPricingTitle => '업체 요금 버전 생성';

  @override
  String get adminVendorPricingSubtitle => '향후 구매는 최신 효력 버전을 사용하며 기존 권한은 구매 시점의 내용을 유지합니다.';

  @override
  String get adminVendorPricingCreated => '주최자 요금 버전을 생성했습니다.';

  @override
  String get adminVendorPricingUpdated => '주최자 요금 버전을 업데이트했습니다.';

  @override
  String get adminVendorExistingPlans => '기존 요금 버전';

  @override
  String get adminPricingUpdate => '버전 업데이트';

  @override
  String get adminVendorSubscriptionTitle => '주최자 구독 관리';

  @override
  String get adminVendorSubscriptionSubtitle => '요금 버전, 한도 배수 및 만료일을 지정합니다.';

  @override
  String get adminVendorSubscriptionSaved => '주최자 구독을 저장했습니다.';

  @override
  String get recordCategorySalary => '급여';

  @override
  String get recordCategoryBonus => '상여금';

  @override
  String get recordCategoryInvestmentIncome => '투자 수익';

  @override
  String get recordCategoryAllowance => '수당';

  @override
  String get recordCategoryRefund => '환불';

  @override
  String get recordCategoryOtherIncome => '기타 수입';

  @override
  String get languageEnglish => '영어';

  @override
  String get languageChinese => '중국어';

  @override
  String get languageJapanese => '일본어';

  @override
  String get languageKorean => '한국어';

  @override
  String feedbackProcessedBy(String name, String time) {
    return '$name님이 $time에 처리';
  }

  @override
  String relativeStrengthIndex(String value) {
    return 'RSI: $value';
  }

  @override
  String get gamePassed => '통과!';

  @override
  String get gameFailed => '실패';

  @override
  String gameScoreValue(num score) {
    return '점수: $score';
  }

  @override
  String get appTitle => '생활 내비게이션';

  @override
  String get language => '언어';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get passwordRecoveryChoiceTitle => '재설정 방법 선택';

  @override
  String get passwordRecoveryChoiceDescription => '인증 이메일로 직접 재설정하거나 관리자에게 이메일로 도움을 요청하세요.';

  @override
  String get resetByEmailVerification => '인증 이메일로 재설정';

  @override
  String get resetByEmailVerificationDescription => '새 비밀번호를 설정할 수 있는 안전한 링크를 이메일로 보내드립니다.';

  @override
  String get askAdministrator => '관리자에게 요청';

  @override
  String get askAdministratorDescription => '이메일 앱에서 요청을 보내면 관리자가 처리 후 답장합니다.';

  @override
  String get adminPasswordHelpSubject => 'Life Pilot 비밀번호 변경 요청';

  @override
  String adminPasswordHelpBody(String account) {
    return 'Life Pilot에 로그인할 수 없습니다. 비밀번호 변경을 도와주세요.\n\n계정: $account\n\n처리 후 이 이메일 주소로 결과를 회신해 주세요.';
  }

  @override
  String get adminPasswordHelpOpened => '이메일 앱을 열었습니다. 내용을 확인한 후 보내 주세요.';

  @override
  String adminPasswordHelpEmailUnavailable(String email) {
    return '이메일 앱을 열 수 없습니다. $email로 이메일을 보내 주세요.';
  }

  @override
  String get passwordHelpTitle => '기타 재설정 방법';

  @override
  String get passwordHelpDescription => '현재 비밀번호를 잊은 경우 인증 이메일로 재설정하거나 관리자에게 도움을 요청할 수 있습니다.';

  @override
  String get login => '  로그인  ';

  @override
  String get loginAnonymously => '게스트 로그인';

  @override
  String get logout => '로그아웃';

  @override
  String get logoutConfirmation => '현재 계정에서 로그아웃하시겠습니까?';

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
  String get accountSecurity => '계정 보안';

  @override
  String get currentPassword => '현재 비밀번호';

  @override
  String get newPassword => '새 비밀번호';

  @override
  String get changePassword => '비밀번호 변경';

  @override
  String get changePasswordSuccessful => '비밀번호가 변경되었습니다.';

  @override
  String get changePasswordFailed => '현재 비밀번호를 확인한 후 다시 시도해 주세요.';

  @override
  String get currentPasswordIncorrect => '현재 비밀번호가 올바르지 않습니다.';

  @override
  String get passwordMustBeDifferent => '새 비밀번호는 현재 비밀번호와 달라야 합니다.';

  @override
  String get passwordDoesNotMeetPolicy => '새 비밀번호가 보안 요구사항을 충족하지 않습니다. 영문자, 숫자 또는 기호를 추가한 후 다시 시도해 주세요.';

  @override
  String get passwordReauthenticationRequired => '보안을 위해 먼저 이메일 인증으로 비밀번호를 재설정해 주세요.';

  @override
  String get adminPasswordResetTitle => '사용자 비밀번호 재설정 지원';

  @override
  String get adminPasswordResetDescription => '요청한 사용자의 계정 이메일을 입력해 임시 비밀번호를 만드세요. 사용자에게 회신하고 로그인 후 즉시 변경하도록 안내하세요.';

  @override
  String get adminPasswordResetUserEmail => '사용자 이메일';

  @override
  String get adminPasswordResetSend => '임시 비밀번호 만들기';

  @override
  String adminTemporaryPasswordCreated(String email) {
    return '$email의 임시 비밀번호를 만들었습니다.';
  }

  @override
  String get adminTemporaryPasswordLabel => '임시 비밀번호';

  @override
  String get adminTemporaryPasswordInstruction => '복사하여 사용자에게 회신하고, 로그인 후 즉시 \'계정 보안\'에서 변경하도록 안내하세요.';

  @override
  String get adminTemporaryPasswordCopy => '임시 비밀번호 복사';

  @override
  String get adminTemporaryPasswordCopied => '임시 비밀번호를 복사했습니다.';

  @override
  String get adminPasswordResetUserNotFound => '이 이메일의 사용자를 찾을 수 없습니다.';

  @override
  String get adminPasswordResetFailed => '임시 비밀번호를 만들 수 없습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get publishedSubmission => '공개됨';

  @override
  String get publishedSubmissionTooltip => '이 정보는 공개되어 모든 사용자가 볼 수 있습니다.';

  @override
  String get unpublishedSubmission => '아직 공개되지 않음';

  @override
  String get unpublishedSubmissionTooltip => '이 정보는 검토 대기 중이며 현재 본인과 관리자만 볼 수 있습니다.';

  @override
  String get leaveGameConfirmation => '게임을 종료하고 이전 페이지로 돌아가시겠습니까?';

  @override
  String get questionBank => '문제 은행';

  @override
  String get adminQuestionBank => '관리자 문제 은행';

  @override
  String get myQuestionBank => '내 문제 은행';

  @override
  String get localQuestionBankOnly => '기기 모드에서는 이 기기의 개인 문제 은행만 사용할 수 있으며 관리자 문제 은행은 사용할 수 없습니다.';

  @override
  String get addQuestion => '문제 추가';

  @override
  String get question => '문제';

  @override
  String get correctAnswer => '정답';

  @override
  String get categoryLabel => '분류';

  @override
  String get secondaryCategoryLabel => '하위 분류';

  @override
  String get amountLabel => '값';

  @override
  String get dataExportSummarySheet => '내보내기 요약';

  @override
  String get questionGroup => '문제 그룹';

  @override
  String get answerOptions => '답안 선택지';

  @override
  String get answerOptionsHint => '선택지는 쉼표로 구분하세요';

  @override
  String get scrambledWords => '재배열할 단어';

  @override
  String get speakingText => '말할 문장';

  @override
  String get requiredField => '필수 입력 항목입니다';

  @override
  String get twoOptionsRequired => '답안 선택지를 두 개 이상 입력하세요';

  @override
  String get questionAdded => '문제가 내 문제 은행에 추가되었습니다';

  @override
  String get grammarQuestionHelp => '일반 문법 문제는 We are young 같은 완성된 문장을 입력하면 are가 자동으로 빈칸이 됩니다. plural 카테고리는 head와 heads만 입력하세요.';

  @override
  String get sentenceQuestionHelp => 'mother 또는 I love apples와 같이 완성된 단어나 올바른 문장만 입력하세요. 재배열 형식으로 자동 변환됩니다.';

  @override
  String get grammarBaseWord => '기본 단어(예: head)';

  @override
  String get completedGrammarQuestion => '정답이 포함된 완성된 문제(예: We are young)';

  @override
  String get grammarAnswerMustAppear => '빈칸을 자동으로 만들 수 있도록 완성된 문제에 정답을 포함하세요.';

  @override
  String get questionExample => '문제 예시';

  @override
  String get answerExample => '정답 예시';

  @override
  String get sentenceOrWord => '완성된 단어 또는 올바른 문장';

  @override
  String get customQuestionGroup => '+ 새 카테고리 만들기';

  @override
  String get newQuestionGroup => '새 카테고리 이름';

  @override
  String get questionGroupLevelNumber => '카테고리 뒤의 level 숫자(비워 두면 1)';

  @override
  String get questionGroupLevelRange => 'level 숫자는 1에서 30 사이여야 합니다.';

  @override
  String get speakingQuestionHelp => '사용자가 소리 내어 읽을 단어나 문장을 입력하세요. 예: Nice to meet you.';

  @override
  String get translationQuestionHelp => '문제에는 원문, 정답에는 번역을 입력하세요. 같은 그룹에 3문제 이상 만들어야 오답 두 개를 생성할 수 있습니다.';

  @override
  String get japaneseTranslationQuestionHelp => '문제에는 일본어, 정답에는 번역을 입력하세요. 같은 그룹에 3문제 이상 만드세요.';

  @override
  String get koreanTranslationQuestionHelp => '문제에는 한국어, 정답에는 번역을 입력하세요. 같은 그룹에 3문제 이상 만드세요.';

  @override
  String get wordSearchQuestionHelp => '문제에는 영어 단어, 정답에는 뜻을 입력하세요. 예: apple／사과.';

  @override
  String get duplicateQuestion => '같은 문제와 정답이 선택한 문제 그룹에 이미 있습니다.';

  @override
  String get myQuestionBankEmpty => '이 레벨에서 사용할 수 있는 문제가 없습니다. 먼저 문제를 추가하세요.';

  @override
  String get threeQuestionsRequired => '현재 레벨에서 사용할 수 있는 문제가 전체 문제 은행에 3개 이상 필요합니다.';

  @override
  String get questionBankInsufficient => '선택한 문제 은행에 이 레벨에서 사용할 문제가 부족합니다.';

  @override
  String get myQuestions => '내 문제';

  @override
  String get noMyQuestions => '이 게임에 추가한 문제가 아직 없습니다.';

  @override
  String get questionDeleted => '문제가 삭제되었습니다';

  @override
  String get editQuestion => '문제 수정';

  @override
  String get questionUpdated => '문제가 수정되었습니다';

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
  String get completeAndReview => '완료 및 돌아보기';

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
  String get pointGroup => '그룹';

  @override
  String get stockSelectDate => '주식 날짜';

  @override
  String get statusInProgress => '진행 중';

  @override
  String get statusNotStarted => '시작 전';

  @override
  String get statusCompleted => '완료';

  @override
  String get statusPending => '미처리';

  @override
  String get noData => '데이터가 없습니다';

  @override
  String get accountMaster => '그룹';

  @override
  String get accountRecords => '가계부 기록';

  @override
  String get todayIncomeExpense => '오늘의 수입과 지출';

  @override
  String get todayPoints => '오늘의 핵심 포인트';

  @override
  String get totalAmount => '총 금액';

  @override
  String get totalPoints => '총 포인트';

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
  String get businessPlan => '비즈니스 플랜';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get search => '검색';

  @override
  String get recordSearchHint => '설명 또는 하위 분류 검색';

  @override
  String get recordAllCategories => '전체 분류';

  @override
  String get recordNetChange => '순변동';

  @override
  String get moreActions => '더보기';

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
  String get businessHours => '영업시간';

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
  String get homeJourneyReviewHint => '일정을 완료하며 추억, 수입·지출, 포인트를 함께 기록할 수 있습니다';

  @override
  String get todayLifeOverview => '오늘의 생활 요약';

  @override
  String get todayLifeOverviewHint => '일정, 수입·지출, 포인트를 한곳에서 확인하고 항목을 눌러 자세히 볼 수 있습니다.';

  @override
  String get homeInsightDiscover => '오늘 일정이 없습니다. 관심 있는 이벤트나 장소부터 찾아보세요.';

  @override
  String get homeInsightConnectAccounts => '수입·지출과 포인트 계정을 선택하면 일정 완료 시 한 번에 정리할 수 있습니다.';

  @override
  String get homeInsightReadyForReview => '오늘 일정이 추억, 수입·지출, 포인트와 연결되어 한 번에 정리할 수 있습니다.';

  @override
  String get quickAddAccounting => '빠른 수입·지출 기록';

  @override
  String get quickAddPoints => '빠른 포인트 기록';

  @override
  String get findRecommendedEvent => '추천 이벤트 찾기';

  @override
  String get findRecommendedPlace => '추천 장소 찾기';

  @override
  String get startsToday => '오늘 시작';

  @override
  String get alreadyStarted => '이미 시작됨';

  @override
  String get startsTomorrow => '내일 시작';

  @override
  String startsInDays(int count) {
    return '$count일 후 시작';
  }

  @override
  String eventSessionCount(int count) {
    return '총 $count회';
  }

  @override
  String memoryCountForDay(int count) {
    return '추억 $count개';
  }

  @override
  String gameProgressSummary(int passed, int total) {
    return '$total개 중 $passed개 레벨 통과';
  }

  @override
  String gameRecentBestScore(String score) {
    return '최근 최고 $score';
  }

  @override
  String get addToSchedule => '일정에 추가';

  @override
  String get scheduleDuplicateConfirmation => '이 항목은 이미 캘린더에 있습니다. 다시 추가할까요?';

  @override
  String get clickHereToSeeMore => '더 보기 클릭';

  @override
  String get close => '닫기';

  @override
  String get weatherForecast => '일기 예보';

  @override
  String get weatherTemperature => '기온';

  @override
  String get weatherMinimum => '최저';

  @override
  String get weatherMaximum => '최고';

  @override
  String get weatherThunderstorm => '뇌우';

  @override
  String get weatherDrizzle => '이슬비';

  @override
  String get weatherRain => '비';

  @override
  String get weatherSnow => '눈';

  @override
  String get weatherMist => '안개';

  @override
  String get weatherClear => '맑음';

  @override
  String get weatherClouds => '흐림';

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
  String get accountDeletionRequestDescription => '요청이 관리자에게 전송되며, 관리자가 승인한 후 계정과 데이터가 삭제됩니다.';

  @override
  String get continueLabel => '계속';

  @override
  String get accountDeletionEmailUnavailable => '이메일 앱을 열 수 없습니다. minavi@alumni.nccu.edu.tw로 문의해 주세요.';

  @override
  String get requestDataExport => '개인 데이터 내보내기 요청';

  @override
  String get dataExportRequestDescription => '클라우드와 기기의 개인 데이터를 Excel 파일로 직접 다운로드합니다.';

  @override
  String get dataExportIncludedPages => '다운로드 내용: 캘린더, 추억, 회계 기록 및 포인트 기록입니다.';

  @override
  String get dataExportEmailUnavailable => '이메일 앱을 열 수 없습니다. minavi@alumni.nccu.edu.tw로 문의해 주세요.';

  @override
  String get accountDeletionCompleted => '삭제 요청이 관리자에게 전송되었습니다.';

  @override
  String accountDeletionFailed(Object message) {
    return '계정 삭제 실패: $message';
  }

  @override
  String get accountDeletionCloudOnly => '계정 삭제 요청은 클라우드 모드에서만 사용할 수 있습니다. 먼저 저장 위치를 클라우드로 변경하세요.';

  @override
  String get accountDeletionPending => '신청 처리 중';

  @override
  String get accountDeletionPendingDescription => '계정 삭제 신청이 관리자 확인을 기다리고 있습니다. 삭제를 원하지 않으면 신청 취소를 요청할 수 있습니다.';

  @override
  String get accountDeletionCancelRequest => '신청 취소';

  @override
  String get accountDeletionCancellationSubmitted => '취소 신청을 보냈습니다. 관리자 확인을 기다리고 있습니다.';

  @override
  String get accountDeletionCancellationPending => '취소 신청이 관리자 확인을 기다리고 있습니다.';

  @override
  String get adminAccountDeletionCancellationRequested => '사용자가 계정 삭제 신청 취소를 요청했습니다.';

  @override
  String get adminAccountDeletionConfirmCancellation => '취소 확인';

  @override
  String get adminAccountDeletionCancellationConfirmed => '취소를 확인하고 기존 삭제 신청을 제거했습니다.';

  @override
  String get adminAccountDeletionCompleted => '계정과 관련 데이터가 삭제되었습니다.';

  @override
  String dataExportCompleted(Object path) {
    return '데이터 내보내기 완료: $path';
  }

  @override
  String dataExportFailed(Object message) {
    return '데이터 내보내기 실패: $message';
  }

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
  String get stockRetry => '최신 데이터 불러오기';

  @override
  String get stockDashboardTitle => '📊 시장 대시보드';

  @override
  String get stockForeignBuy => '외국인 순매수 순위';

  @override
  String get stockForeignSell => '외국인 순매도 순위';

  @override
  String get stockThousandLots => '천 로트';

  @override
  String stockClosingPrice(String value) {
    return '종가: $value';
  }

  @override
  String stockTradingVolume(String value) {
    return '거래량: $value로트';
  }

  @override
  String get editRecord => '내역 편집';

  @override
  String get manualEntry => '직접 추가';

  @override
  String get recordDate => '날짜';

  @override
  String get recordTime => '시간';

  @override
  String get recordValue => '값';

  @override
  String get recordPrimaryCategory => '1차 분류';

  @override
  String get recordSecondaryCategory => '2차 분류(선택)';

  @override
  String get recordCategoryUncategorized => '미분류';

  @override
  String get recordCategoryReserved => '보존 항목';

  @override
  String get recordCategoryFood => '식비';

  @override
  String get recordCategoryClothing => '의류';

  @override
  String get recordCategoryHousing => '주거';

  @override
  String get recordCategoryTransportation => '교통';

  @override
  String get recordCategoryEducation => '교육';

  @override
  String get recordCategoryEntertainment => '여가';

  @override
  String get recordCategoryVirtue => '덕성';

  @override
  String get recordCategoryIntelligence => '지성';

  @override
  String get recordCategoryFitness => '체력';

  @override
  String get recordCategorySocial => '사회성';

  @override
  String get recordCategoryArts => '예술';

  @override
  String get recordTotal => '합계';

  @override
  String get recordPleaseConfirm => '확인해 주세요';

  @override
  String get recordSubmit => '제출';

  @override
  String get accountNew => '새 계정';

  @override
  String get accountName => '계정 이름';

  @override
  String get accountCreate => '만들기';

  @override
  String get accountDefault => '기본';

  @override
  String get accountAlreadyExists => '계정이 이미 존재합니다';

  @override
  String accountDeleteConfirmation(String name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String get accountSetMainCurrency => '기준 통화 설정';

  @override
  String get accountSwitchCurrency => '통화 전환';

  @override
  String get currencyLabel => '통화';

  @override
  String get accountingSpeechHint => '예: 금액 추가/차감';

  @override
  String get pointsSpeechHint => '예: 포인트 추가/차감';

  @override
  String get accountingUnit => '';

  @override
  String get pointsUnit => '포인트';

  @override
  String get eventIncome => '수입';

  @override
  String get eventExpense => '지출';

  @override
  String get eventPointIncrease => '가점';

  @override
  String get eventPointDecrease => '감점';

  @override
  String get eventCompleted => '일정을 완료했습니다';

  @override
  String eventCompletedWithRecords(String items) {
    return '일정을 완료했습니다: $items';
  }

  @override
  String get eventMemory => '추억';

  @override
  String get eventRefresh => '추천 이벤트 업데이트';

  @override
  String get eventRefreshSucceeded => '추천 이벤트를 업데이트했습니다.';

  @override
  String get eventRefreshFailed => '추천 이벤트를 업데이트하지 못했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get eventRefreshRunning => '추천 이벤트를 업데이트하고 있습니다. 잠시 후 다시 확인해 주세요.';

  @override
  String get questionHasAnswersDeleteBlocked => '이 문제에는 답변 기록이 있어 삭제할 수 없습니다. 대신 비활성화할 수 있습니다.';

  @override
  String get questionStatus => '문제 상태';

  @override
  String get allQuestionStatuses => '모든 상태';

  @override
  String get activeQuestion => '사용 중';

  @override
  String get inactiveQuestion => '비활성';

  @override
  String get deactivateQuestion => '문제 비활성화';

  @override
  String get reactivateQuestion => '문제 다시 활성화';

  @override
  String get questionDeactivated => '문제가 비활성화되었습니다.';

  @override
  String get questionReactivated => '문제가 다시 활성화되었습니다.';

  @override
  String get questionStatusUpdateFailed => '문제 상태를 업데이트하지 못했습니다. 다시 시도하세요.';

  @override
  String get mapCoordinateBackfill => '지도 좌표 채우기';

  @override
  String get mapCoordinateBackfillFailed => '지도 좌표를 채울 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String mapCoordinateBackfillResult(int saved, int remaining, String coverage) {
    return '$saved개 저장, $remaining개 남음, 적용률 $coverage%.';
  }

  @override
  String get calendarSharing => '공유 캘린더';

  @override
  String get calendarInvite => '조회자 초대';

  @override
  String get calendarInviteHint => '이메일을 쉼표 또는 줄바꿈으로 구분해 입력하세요';

  @override
  String get calendarSentInvitations => '보낸 초대';

  @override
  String get calendarReceivedInvitations => '받은 초대';

  @override
  String get calendarInvitationPending => '대기 중';

  @override
  String get calendarInvitationAccepted => '수락됨';

  @override
  String get calendarInvitationDeclined => '거절됨';

  @override
  String get calendarInvitationRevoked => '공유 중지됨';

  @override
  String get calendarInvitationAccept => '수락';

  @override
  String get calendarInvitationDecline => '거절';

  @override
  String get calendarInvitationRevoke => '공유 중지';

  @override
  String get calendarInvitationSent => '초대를 보냈습니다.';

  @override
  String get calendarSharingUpdated => '캘린더 공유가 업데이트되었습니다.';

  @override
  String get calendarInvitationFailed => '캘린더 초대를 업데이트할 수 없습니다.';

  @override
  String get calendarInvitationQuotaExceeded => '캘린더 공유 한도에 도달했습니다. 기존 공유를 삭제하거나 요금제를 변경하세요.';

  @override
  String get calendarInvitationDuplicate => '이 일정은 이미 이 계정과 공유되어 있습니다.';

  @override
  String get calendarInvitationAccountNotFound => '계정을 찾을 수 없습니다.';

  @override
  String get calendarInvitationSelfInvite => '자신의 계정은 초대할 수 없습니다.';

  @override
  String get calendarInvitationEventUnavailable => '선택한 일정이 없거나 공유할 수 없습니다. 새로고침 후 다시 선택해 주세요.';

  @override
  String get calendarInvitationStateChanged => '초대 상태가 변경되었습니다. 새로고침 후 다시 시도해 주세요.';

  @override
  String calendarInvitationFailedWithReason(String reason) {
    return '캘린더 초대를 업데이트할 수 없습니다: $reason';
  }

  @override
  String get adminSubscriptionExtended => '구독 기간이 90일 연장되었습니다.';

  @override
  String get adminSubscriptionExtend90Days => '90일 연장';

  @override
  String get adminSubscriptionExtensionDays => '연장 일수';

  @override
  String get adminSubscriptionExtend => '연장';

  @override
  String get adminSubscriptionLookupRequired => '먼저 데이터를 조회해 주세요.';

  @override
  String get adminSubscriptionNotFound => '구독 정보가 없습니다';

  @override
  String get adminSubscriptionNotFoundCreate => '이 사용자의 새 구독을 만들 수 있습니다.';

  @override
  String get adminSubscriptionUserNotFound => '사용자 계정을 찾을 수 없습니다';

  @override
  String get adminSubscriptionLoadedForEditing => '현재 구독을 불러왔습니다. 수정 후 저장할 수 있습니다.';

  @override
  String get adminSubscriptionDeleteTitle => '구독 설정 삭제';

  @override
  String adminSubscriptionDeleteConfirmation(String email) {
    return '$email의 구독 및 한도 설정을 삭제할까요? 사용자 데이터는 삭제되지 않습니다.';
  }

  @override
  String get adminSubscriptionDeleted => '구독 및 한도 설정을 삭제했습니다.';

  @override
  String get adminSubscriptionEntitlements => '생성된 한도';

  @override
  String adminSubscriptionDeleteEntitlementConfirmation(String version) {
    return '$version 한도 한 건만 삭제할까요? 다른 한도와 사용자 데이터는 유지됩니다.';
  }

  @override
  String get adminSubscriptionEntitlementDeleted => '이 한도를 삭제했습니다. 다른 한도는 유지됩니다.';

  @override
  String get adminSubscriptionDeleteAll => '모든 구독 및 한도 설정 삭제';

  @override
  String get adminSubscriptionInvalidExtensionDays => '1~3650일 사이의 숫자를 입력하세요.';

  @override
  String adminSubscriptionExtendedDays(int days) {
    return '구독 기간이 $days일 연장되었습니다.';
  }

  @override
  String get days => '일';

  @override
  String calendarSharedBy(String account) {
    return '$account 님이 공유';
  }

  @override
  String get calendarSharedReadOnly => '공유 캘린더 · 읽기 전용';

  @override
  String get calendarShareEvents => '공유할 일정 선택';

  @override
  String get calendarSearchEmail => '이메일';

  @override
  String get calendarSearchEvent => '일정';

  @override
  String get scrollThisArea => '이 영역에서 위아래로 스크롤';

  @override
  String get calendarNoShareableEvents => '공유할 수 있는 일정이 없습니다.';

  @override
  String get calendarSelectEventRequired => '공유할 일정을 하나 이상 선택하세요.';

  @override
  String get calendarStopReceiving => '보기 중지';

  @override
  String get calendarShareAllEvents => '모든 일정 공유';

  @override
  String get calendarNoSharedEvents => '현재 공유 중인 일정이 없습니다.';

  @override
  String get calendarCancelSingleShare => '이 일정 공유 중지';

  @override
  String get calendarCancelAllShares => '모든 공유 중지';

  @override
  String subscriptionUsage(int used, int quota) {
    return '사용 $used／$quota';
  }

  @override
  String subscriptionLocalUsage(int used) {
    return '이 기기: $used개／무제한';
  }

  @override
  String get subscriptionQuotaReached => '현재 요금제의 한도에 도달했습니다. 기존 데이터를 삭제한 후 추가하거나 Plus로 업그레이드하세요.';

  @override
  String subscriptionQuotaReachedDetail(int used, int quota, int remaining) {
    return '클라우드 한도에 도달했습니다. $quota개 중 $used개를 사용 중이며 $remaining개를 더 추가할 수 있습니다. 기존 데이터를 삭제하거나 이 기기로 전환하거나 Plus로 업그레이드하세요.';
  }

  @override
  String get subscriptionImagePlusOnly => '이미지 업로드는 Plus에서 사용할 수 있습니다.';

  @override
  String get subscriptionDeleteRecordHint => '삭제하면 오늘 소계와 총계도 다시 계산됩니다.';

  @override
  String get dataStorageTitle => '저장 위치';

  @override
  String get dataStorageCloud => '클라우드';

  @override
  String get dataStorageLocal => '이 기기';

  @override
  String get dataStorageLocalWarning => '로컬 데이터는 이 기기, 브라우저 및 현재 브라우저 프로필에서만 볼 수 있습니다. 다른 기기, 브라우저 또는 프로필에는 자동으로 나타나지 않습니다. 앱을 삭제하거나 사이트 또는 브라우저 데이터를 지우면 영구적으로 사라질 수 있습니다. 요금제 한도 내에서는 클라우드로 다시 이동할 수 있습니다.';

  @override
  String get dataStorageCloudWarning => '클라우드 데이터는 여러 기기에서 사용할 수 있으며 요금제 한도가 적용됩니다.';

  @override
  String get dataMoveToLocal => '클라우드 데이터를 이 기기로 이동';

  @override
  String get dataMoveToLocalConfirm => '복사와 확인 후 클라우드에서 삭제되며 이 기기, 브라우저 및 현재 브라우저 프로필에서만 볼 수 있습니다. 다른 환경에는 자동으로 나타나지 않으며 사이트 데이터를 지우면 영구적으로 사라질 수 있습니다. 계속할까요?';

  @override
  String get dataMoveToLocalSuccess => '클라우드 데이터를 이 기기로 이동했습니다.';

  @override
  String get dataMoveToLocalFailed => '일부 데이터를 이동하지 못해 클라우드 원본을 유지했습니다.';

  @override
  String get dataStorageLocalPlanRequired => '기기 Plus 결제를 완료하고 관리자가 활성화한 뒤 전환해 주세요.';

  @override
  String get dataUploadToCloud => '로컬 데이터를 클라우드에 업로드(관리자)';

  @override
  String get dataUploadToCloudAction => '로컬 데이터를 클라우드로 이동';

  @override
  String get dataUploadToCloudConfirm => '클라우드 데이터와 충돌하지 않는 항목만 업로드합니다. 실패한 항목은 이 기기에 남습니다. 계속할까요?';

  @override
  String get dataUploadToCloudSuccess => '로컬 데이터를 클라우드에 업로드했습니다.';

  @override
  String get dataUploadToCloudFailed => '일부 로컬 데이터를 업로드하지 못해 이 기기에 유지했습니다.';

  @override
  String dataUploadQuotaExceeded(String resource, int used, int incoming, int quota) {
    return '업로드 취소: $resource은(는) 현재 클라우드에서 $used개를 사용 중이며, 이번 $incoming개를 추가하면 요금제 한도 $quota개를 초과합니다.';
  }

  @override
  String get subscriptionRenewalRequired => '유료 기간이 종료되었습니다. 갱신하거나 모든 클라우드 데이터를 이 기기로 이동할 때까지 클라우드는 읽기 전용입니다.';

  @override
  String get subscriptionPlansTitle => '요금제 및 구독';

  @override
  String get subscriptionCurrentFree => '현재 요금제: 클라우드 무료';

  @override
  String get subscriptionCurrentAdmin => '현재 권한: 관리자(무제한)';

  @override
  String get subscriptionCurrentPlus => '현재 요금제: Plus';

  @override
  String get subscriptionCurrentCloudPlus => '현재: 클라우드 Plus';

  @override
  String get dataClearLocalTitle => '기기 데이터 삭제';

  @override
  String get dataClearLocalConfirm => '이 기기의 모든 개인 데이터를 영구 삭제하며 복구할 수 없습니다. 삭제 후 클라우드 전환을 다시 시도할 수 있습니다. 계속할까요?';

  @override
  String get dataClearLocalAction => '기기 데이터 삭제';

  @override
  String get dataClearLocalSuccess => '기기 데이터를 삭제했습니다';

  @override
  String get dataClearLocalFailed => '기기 데이터를 삭제하지 못했습니다. 잠시 후 다시 시도하세요.';

  @override
  String get subscriptionCurrentLocalPlus => '현재: 로컬 Plus';

  @override
  String subscriptionValidUntil(String date) {
    return '유효 기간: $date';
  }

  @override
  String get subscriptionFreeName => '클라우드 무료';

  @override
  String get subscriptionFreePrice => 'NT\$0';

  @override
  String get subscriptionPlusName => '클라우드 Plus';

  @override
  String get subscriptionPlusPrice => '분기 NT\$129부터';

  @override
  String get subscriptionFreePersonalRecords => '클라우드 저장: 캘린더, 회계, 포인트, 추억 각 최대 30개';

  @override
  String get subscriptionPlusPersonalRecords => '캘린더, 회계, 포인트, 추억 클라우드 데이터 각 300개';

  @override
  String get subscriptionCommonFeatures => '두 요금제 모두 제공';

  @override
  String get subscriptionCommonFeaturesDetail => '캘린더, 회계, 포인트, 추천 이벤트와 장소, 관리자 문제 은행. 기기 저장 데이터는 무제한입니다. 주식과 비즈니스 플랜은 관리자 전용입니다.';

  @override
  String get subscriptionPurchaseComingSoon => '인앱 구독 출시 예정';

  @override
  String get subscriptionPurchaseExplanation => '현재 Plus를 구매할 수 없습니다. 스토어 결제가 시작되면 이 페이지에 공식 가격, 갱신 조건, 구매, 구매 복원 및 구독 관리 기능이 표시됩니다.';

  @override
  String get subscriptionInactiveAccountWarning => '무료 계정은 만료일이 없습니다. 3개월 동안 데이터를 추가하거나 변경하지 않으면 계정과 클라우드 데이터가 자동 삭제됩니다.';

  @override
  String get subscriptionPricingVersion => '현재 버전';

  @override
  String get subscriptionEffectiveDate => '적용일';

  @override
  String get subscriptionQuotaMultiplier => '한도 배수';

  @override
  String get subscriptionQuarterlyPayment => '분기 결제액';

  @override
  String get subscriptionActualQuotaTitle => '현재 버전 및 실제 한도';

  @override
  String get subscriptionImageStorage => '이미지 용량';

  @override
  String get subscriptionNextVersionTitle => '다음 결제에 적용될 최신 버전';

  @override
  String get subscriptionNextCloudVersionTitle => '다음 결제에 적용되는 클라우드 버전';

  @override
  String get subscriptionLatestLocalVersionTitle => '다음 결제에 적용되는 로컬 Plus 버전';

  @override
  String subscriptionVersionOffer(String version, String date, int price) {
    return '$version · $date 적용 · 분기 NT\$$price';
  }

  @override
  String get subscriptionLocalPaidName => '기기 Plus';

  @override
  String subscriptionCloudVersionName(String version) {
    return '클라우드 $version';
  }

  @override
  String subscriptionLocalVersionName(String version) {
    return '기기 $version';
  }

  @override
  String subscriptionNextCloudVersionName(String version) {
    return '다음 결제: 클라우드 $version';
  }

  @override
  String subscriptionNextLocalVersionName(String version) {
    return '다음 결제: 기기 $version';
  }

  @override
  String get subscriptionLocalPaidPrice => '분기 NT\$129';

  @override
  String get subscriptionLocalPaidFeature => '이 기기의 기록과 이미지는 무제한이며 다른 기기에 자동 표시되지 않습니다';

  @override
  String get subscriptionLocalAnswerHistory => '기기 답변 기록 무제한';

  @override
  String get adminPricingTitle => '사용자 요금 버전 생성';

  @override
  String get adminPricingSubtitle => '이후 결제와 추가 구매에만 적용';

  @override
  String get adminPricingRequired => '버전 이름과 모든 숫자를 입력하세요';

  @override
  String get adminPricingCreated => '새 요금 버전이 생성되었습니다. 기존 혜택은 유지됩니다';

  @override
  String get adminPricingUpdated => '사용자 요금 버전이 업데이트되었습니다. 기존 구독 혜택은 유지됩니다';

  @override
  String get adminUserExistingPlans => '기존 사용자 요금 버전';

  @override
  String get adminPricingDeleteTitle => '요금 버전 삭제';

  @override
  String adminPricingDeleteConfirmation(String name) {
    return '$name을(를) 삭제하시겠습니까? 어떤 구독이나 권한에서도 사용하지 않는 경우에만 삭제할 수 있습니다.';
  }

  @override
  String get adminPricingDeleted => '요금 버전이 삭제되었습니다.';

  @override
  String get adminPricingDeleteInUse => '이 요금 버전은 구독 또는 권한에서 사용 중이므로 삭제할 수 없습니다.';

  @override
  String adminPricingCreateFailed(String error) {
    return '요금 버전을 저장할 수 없습니다: $error';
  }

  @override
  String get adminPricingVersionName => '버전 이름';

  @override
  String get adminPricingVersionHint => '예: 2026-Q4';

  @override
  String get adminPricingEffectiveDate => '적용일';

  @override
  String get adminPricingCreate => '버전 생성';

  @override
  String get adminPricingQuarterlyPrice => '분기 요금 (TWD)';

  @override
  String get adminPricingCalendarQuota => '일정 수';

  @override
  String get adminPricingAccountingQuota => '회계 내역';

  @override
  String get adminPricingPointQuota => '포인트 내역';

  @override
  String get adminPricingMemoryQuota => '추억';

  @override
  String get adminPricingGameQuota => '사용자 문제';

  @override
  String get adminPricingShareQuota => '일정 공유 인원';

  @override
  String get adminPricingImageQuota => '이미지 용량 (MB)';

  @override
  String get adminPricingAnswerDays => '답변 기록 일수';

  @override
  String get adminPricingLocalZeroUnlimited => '로컬 Plus에서 한도 항목의 0은 무제한을 의미합니다.';

  @override
  String subscriptionDowngradeWarning(String date) {
    return '클라우드 데이터가 무료 한도를 초과했습니다. $date까지 초과 데이터를 이동하거나 삭제하세요.';
  }

  @override
  String subscriptionOverageItem(String resource, int used, int quota, int excess) {
    return '$resource: $used/$quota ($excess개 초과)';
  }

  @override
  String get adminSubscriptionTitle => '구독 관리';

  @override
  String get adminSubscriptionSubtitle => '구매 당시 요금과 한도 적용';

  @override
  String get adminSubscriptionEmail => '사용자 이메일';

  @override
  String get adminSubscriptionPlan => '요금제';

  @override
  String get adminSubscriptionFree => '무료';

  @override
  String get adminSubscriptionPaid => '유료';

  @override
  String get adminSubscriptionNoPricing => '먼저 요금 버전을 생성하세요';

  @override
  String get adminSubscriptionSaved => '구독 설정을 저장했습니다';

  @override
  String adminSubscriptionSaveFailed(String error) {
    return '저장 실패: $error';
  }

  @override
  String get adminSubscriptionNoExpiry => '무료 요금제는 만료일이 없습니다';

  @override
  String get adminSubscriptionInactiveWarning => '3개월간 변경이 없으면 계정과 클라우드 데이터가 삭제됩니다.';

  @override
  String get adminSubscriptionAddQuota => '현재 혜택을 유지하고 한도 추가';

  @override
  String get adminSubscriptionAddQuotaHint => '새 한도를 만료되지 않은 한도에 더합니다';

  @override
  String get adminSubscriptionStoragePlan => '저장 요금제';

  @override
  String get adminSubscriptionCloud => '클라우드';

  @override
  String get adminSubscriptionLocal => '기기 무제한';

  @override
  String get adminSubscriptionPricingVersion => '요금 버전';

  @override
  String get adminSubscriptionMultiplier => '한도 배수';

  @override
  String adminSubscriptionTimes(int count) {
    return '$count배';
  }

  @override
  String get adminSubscriptionExpiry => '혜택 만료일';

  @override
  String get adminSubscriptionNote => '추가 설명';

  @override
  String get adminSubscriptionSave => '구독 저장';

  @override
  String get dataCleanupTitle => '데이터 정리';

  @override
  String get dataCleanupAction => '확인 후 정리';

  @override
  String get dataCleanupTargetEmail => '사용자 Email (비워두면 본인)';

  @override
  String get dataCleanupLocalExplanation => '기기 데이터는 무제한입니다. 이 기기의 모든 개인 데이터를 삭제할 수 있습니다.';

  @override
  String get dataCleanupCloudExplanation => '클라우드 초과 현황을 확인한 뒤 초과분만 또는 전체 데이터를 삭제할 수 있습니다.';

  @override
  String get dataCleanupNoOverage => '현재 한도를 초과한 클라우드 데이터가 없습니다.';

  @override
  String get dataCleanupExcess => '초과분 삭제';

  @override
  String get dataCleanupAll => '전체 삭제';

  @override
  String get dataCleanupConfirmTitle => '삭제 확인';

  @override
  String get dataCleanupExcessConfirm => '현재 한도를 초과한 데이터만 삭제할까요? 복구할 수 없습니다.';

  @override
  String get dataCleanupAllConfirm => '선택한 저장소의 모든 개인 데이터를 삭제할까요? 복구할 수 없습니다.';

  @override
  String get dataCleanupSuccess => '데이터 정리가 완료되었습니다';

  @override
  String get dataCleanupFailed => '데이터 정리에 실패했습니다';

  @override
  String get scheduleAlreadyStarted => '일정이 이미 시작됨';

  @override
  String scheduleStartsInMinutes(int count) {
    return '$count분 후 시작';
  }

  @override
  String scheduleStartsInHours(int count) {
    return '$count시간 후 시작';
  }

  @override
  String get endsToday => '이미 시작됨, 오늘 종료';

  @override
  String ongoingUntil(String date) {
    return '$date까지 진행 중';
  }

  @override
  String memoryCountForMonth(int count) {
    return '이번 달 $count개';
  }

  @override
  String gameRecentPracticeSummary(int attempts, int passed) {
    return '최근 $attempts회 연습, $passed회 통과';
  }

  @override
  String scheduleConflictCount(int count) {
    return '오늘과 내일 일정 시간이 $count건 겹칩니다';
  }

  @override
  String scheduleConflictBeforeSave(int count, String details) {
    return '이 시간이 완료되지 않은 일정 $count개와 겹칩니다:\n$details\n그래도 저장할까요?';
  }

  @override
  String tomorrowScheduleCount(int count) {
    return '내일 일정 $count개';
  }

  @override
  String nextFreeHour(String startTime, String endTime) {
    return '오늘 $startTime~$endTime 일정 없음';
  }

  @override
  String get scheduleNeedsReview => '일정이 종료되었습니다. 완료 여부를 확인해 주세요.';

  @override
  String scheduleNeedsReviewCount(int count) {
    return '확인이 필요한 일정 $count개';
  }

  @override
  String get scheduleAwaitingReview => '확인 대기 일정';

  @override
  String homeInsightReviewOverdue(int count) {
    return '오늘 종료된 일정 $count개가 아직 확인되지 않았습니다. 중요한 일을 확인해 주세요.';
  }

  @override
  String homeInsightResolveConflicts(int count) {
    return '오늘과 내일 일정 $count개의 시간이 겹칩니다. 먼저 일정을 조정해 보세요.';
  }

  @override
  String memoryJourneySummary(int memoryCount, int dayCount, int cityCount) {
    return '불러온 추억 $memoryCount개 · $dayCount일 · $cityCount개 도시';
  }

  @override
  String viewRemainingSchedules(int count) {
    return '나머지 일정 $count개 보기';
  }

  @override
  String viewRemainingRecommendations(int count) {
    return '추천 $count개 더 보기';
  }

  @override
  String scheduleConflictToday(int count) {
    return '오늘 일정 시간 겹침 $count건';
  }

  @override
  String scheduleConflictTomorrow(int count) {
    return '내일 일정 시간 겹침 $count건';
  }

  @override
  String get weekendEvent => '주말 행사';

  @override
  String multiDayEvent(int count) {
    return '연속 $count일';
  }

  @override
  String continueLevel(int level) {
    return '$level단계 계속하기';
  }

  @override
  String get moduleAuthorization => '기능 권한';

  @override
  String get moduleAuthorizationDescription => '일반 사용자에게 추가로 허용할 기능을 설정합니다. 홈과 기능 메뉴에 함께 적용됩니다.';

  @override
  String get moduleAuthorizationSearchFirst => '먼저 사용자 이메일을 입력하고 검색하세요.';

  @override
  String get moduleAuthorizationNoAccess => '허용된 추가 기능이 없습니다.';

  @override
  String get moduleAuthorizationSaved => '기능 권한이 업데이트되었습니다.';

  @override
  String get moduleAuthorizationLoadFailed => '기능 권한을 불러올 수 없습니다. 계정을 확인하고 다시 시도하세요.';

  @override
  String get moduleAuthorizationNotDeployed => '기능 권한이 아직 배포되지 않았습니다. 먼저 Supabase에서 권한 SQL을 실행하세요.';

  @override
  String get moduleAuthorizationUserNotFound => '해당 이메일의 사용자를 찾을 수 없습니다.';

  @override
  String get moduleAuthorizationSaveFailed => '기능 권한이 올바르게 업데이트되지 않았습니다. 다시 검색한 후 재시도하세요.';

  @override
  String get quotaFreePeriodTitle => '용량 무제한 프로모션';

  @override
  String get quotaFreePeriodDescription => '이 기간에 추가한 클라우드 데이터는 요금제 한도에 포함되지 않습니다. 종료 후에는 기존 한도가 자동 적용됩니다.';

  @override
  String get quotaFreePeriodName => '프로모션 이름';

  @override
  String get quotaFreePeriodStart => '시작 일시';

  @override
  String get quotaFreePeriodEnd => '종료 일시';

  @override
  String get quotaFreePeriodEnabled => '이 기간 사용';

  @override
  String get quotaFreePeriodAutomaticHint => '설정한 시작 시각부터 종료 시각까지만 용량 제한을 중지합니다.';

  @override
  String get quotaFreePeriodInvalidRange => '종료 일시는 시작 일시보다 늦어야 합니다.';

  @override
  String get quotaFreePeriodSaved => '용량 무제한 프로모션을 저장했습니다.';

  @override
  String get quotaFreePeriodSaveFailed => '용량 무제한 프로모션을 저장하지 못했습니다.';

  @override
  String get quotaFreePeriodClear => '설정 삭제';

  @override
  String get quotaFreePeriodClearConfirm => '용량 무제한 기간을 삭제할까요? 기존 요금제 한도가 즉시 적용됩니다.';

  @override
  String get quotaFreePeriodCleared => '용량 무제한 프로모션을 삭제했습니다.';

  @override
  String get quotaFreePeriodNew => '기간 만들기';

  @override
  String get quotaFreePeriodEdit => '기간 수정';

  @override
  String get quotaFreePeriodEmpty => '설정된 용량 무제한 기간이 없습니다.';

  @override
  String get quotaFreePeriodUnnamed => '이름 없는 프로모션';

  @override
  String get quotaFreePeriodActive => '현재 적용 중';

  @override
  String get quotaFreePeriodScheduled => '시작 예정';

  @override
  String get quotaFreePeriodEnded => '종료됨';

  @override
  String get quotaFreePeriodDisabled => '사용 안 함';

  @override
  String get country => '국가';

  @override
  String get coverPhotoOptional => '표지 사진(선택)';

  @override
  String get choosePhoto => '사진 선택';

  @override
  String get replacePhoto => '변경';

  @override
  String get allCities => '모든 도시';

  @override
  String get switchToList => '목록으로 전환';

  @override
  String get switchToMap => '지도로 전환';

  @override
  String get countryTaiwan => '대만';

  @override
  String get countryJapan => '일본';

  @override
  String get countrySouthKorea => '대한민국';

  @override
  String get countrySingapore => '싱가포르';

  @override
  String get countryUnitedStates => '미국';

  @override
  String get countryCanada => '캐나다';

  @override
  String get countryChina => '중국';

  @override
  String get countryHongKong => '홍콩';

  @override
  String get countryMacau => '마카오';

  @override
  String get countryThailand => '태국';

  @override
  String get countryVietnam => '베트남';

  @override
  String get countryMalaysia => '말레이시아';

  @override
  String get countryIndonesia => '인도네시아';

  @override
  String get countryPhilippines => '필리핀';

  @override
  String get countryAustralia => '호주';

  @override
  String get countryNewZealand => '뉴질랜드';

  @override
  String get countryUnitedKingdom => '영국';

  @override
  String get countryFrance => '프랑스';

  @override
  String get countryGermany => '독일';

  @override
  String get countryItaly => '이탈리아';

  @override
  String get countrySpain => '스페인';

  @override
  String get countryNetherlands => '네덜란드';

  @override
  String get countrySwitzerland => '스위스';

  @override
  String get countryIndia => '인도';

  @override
  String get countryUnitedArabEmirates => '아랍에미리트';

  @override
  String get feedbackPurpose => '목적';

  @override
  String get feedbackContent => '내용';

  @override
  String get captureScreen => '화면 캡처';

  @override
  String get feedbackRequired => '목적과 내용을 입력하세요.';

  @override
  String get feedbackSent => '피드백을 보냈습니다.';

  @override
  String feedbackSendFailed(String error) {
    return '피드백을 보낼 수 없습니다: $error';
  }

  @override
  String get accessDenied => '접근 권한이 없습니다';

  @override
  String get selectTemplate => '템플릿 선택';

  @override
  String get planTitle => '계획 제목';

  @override
  String get create => '만들기';

  @override
  String get enterAnswer => '답변 입력';

  @override
  String get previous => '이전';

  @override
  String get next => '다음';

  @override
  String get loadingSections => '섹션 로드 중…';

  @override
  String get loading => '로드 중…';

  @override
  String get notFilled => '아직 입력하지 않음';

  @override
  String get untitledPlan => '제목 없는 계획';

  @override
  String get openChatGPT => 'ChatGPT 열기';

  @override
  String get unableToLoadDocument => '이 문서를 불러올 수 없습니다.';

  @override
  String gameTitleScore(String game, num score) {
    return '$game ($score/100)';
  }

  @override
  String congratulationsScore(num score) {
    return '축하합니다! 점수: $score';
  }

  @override
  String get wordSearchTitle => '단어 찾기';

  @override
  String get translationTitle => '번역';

  @override
  String get socialTitle => '사회성';

  @override
  String get speakingTitle => '말하기';

  @override
  String get englishRpgAdventureTitle => '영어 RPG 모험';

  @override
  String get answerHere => '여기에 답변';

  @override
  String get check => '확인';

  @override
  String get restart => '다시 시작';

  @override
  String get scratchGameTitle => 'Scratch 게임';

  @override
  String get scratchMazeTitle => 'Scratch 미로 게임';

  @override
  String get blocklyEditor => 'Blockly 편집기';

  @override
  String get puzzleMapTitle => '지도 퍼즐';

  @override
  String get hint => '힌트';

  @override
  String get monominoGameTitle => '모노미노 게임';

  @override
  String get checkPath => '경로 확인';

  @override
  String get polyominoGameTitle => '폴리오미노 게임';

  @override
  String get noPipes => '파이프가 없습니다';

  @override
  String get go => '이동';

  @override
  String get wordSentenceBuilderTitle => '단어와 문장 만들기';

  @override
  String priceEarningsRatio(String value) {
    return 'PER: $value';
  }

  @override
  String get stockNet => '순변동';

  @override
  String deleteNumberedItem(int number, String name) {
    return '$number번 항목 \'$name\'을(를) 삭제할까요?';
  }
}
