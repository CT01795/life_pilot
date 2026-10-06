// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get accessDenied => '沒有使用權限';

  @override
  String get activityName => '活動名稱';

  @override
  String get add => '新增';

  @override
  String get ageMax => '最大年齡';

  @override
  String get ageMin => '最低年齡';

  @override
  String get ai => 'AI助理';

  @override
  String get alarmUpdateFailed => '提醒設定失敗，請稍後再試';

  @override
  String get allCities => '全部城市';

  @override
  String get alreadyStarted => '已經開始';

  @override
  String get amountLabel => '值';

  @override
  String get answerExample => '答案範例';

  @override
  String get answerHere => '在這裡輸入答案';

  @override
  String get answerOptions => '答案選項';

  @override
  String get answerOptionsHint => '請使用逗號分隔選項';

  @override
  String get appTitle => '生活導航';

  @override
  String get askAdministrator => '請管理員協助';

  @override
  String get askAdministratorDescription => '開啟郵件程式寄出申請；管理員處理後會回覆你的信箱。';

  @override
  String get back => '返回';

  @override
  String get blocklyEditor => 'Blockly 編輯器';

  @override
  String get cancel => '取消';

  @override
  String get cancelAlarm => '取消鬧鐘';

  @override
  String get captureScreen => '擷取畫面';

  @override
  String get categoryLabel => '分類';

  @override
  String get check => '檢查';

  @override
  String get checkPath => '檢查路徑';

  @override
  String get choosePhoto => '選擇照片';

  @override
  String get clear => '清除';

  @override
  String get clickHereToSeeMore => '點我看更多';

  @override
  String get close => '關閉';

  @override
  String get completeAndReview => '完成並回顧';

  @override
  String get confirm => '確定';

  @override
  String get confirmDelete => '確定刪除?';

  @override
  String congratulationsScore(num score) {
    return '恭喜！得分：$score';
  }

  @override
  String get continueLabel => '繼續';

  @override
  String continueLevel(int level) {
    return '繼續第 $level 關';
  }

  @override
  String get correctAnswer => '正確答案';

  @override
  String get coverPhotoOptional => '封面照片（選填）';

  @override
  String get create => '建立';

  @override
  String get dataCleanupAction => '查看並清理';

  @override
  String get dataCleanupAll => '全部清除';

  @override
  String get dataCleanupAllConfirm => '確定清除所選儲存位置的全部個人資料嗎？刪除後無法復原。';

  @override
  String get dataCleanupConfirmTitle => '確認刪除';

  @override
  String get dataCleanupExcess => '只清超額';

  @override
  String get dataCleanupExcessConfirm => '確定只刪除超過目前額度的資料嗎？刪除後無法復原。';

  @override
  String get dataCleanupFailed => '資料清理失敗';

  @override
  String get dataCleanupNoOverage => '目前沒有超過額度的雲端資料。';

  @override
  String get dataCleanupSuccess => '資料清理完成';

  @override
  String get dataCleanupTargetEmail => '使用者 Email（留空為自己）';

  @override
  String get dataCleanupTitle => '清理資料';

  @override
  String get dataClearLocalAction => '清除本機資料';

  @override
  String get dataClearLocalConfirm => '這會永久清除這台裝置上的所有個人資料，且無法復原。清除後可再嘗試切換至雲端。確定繼續嗎？';

  @override
  String get dataClearLocalFailed => '無法清除本機資料，請稍後再試';

  @override
  String get dataClearLocalSuccess => '本機資料已清除';

  @override
  String get dataClearLocalTitle => '清除本機資料';

  @override
  String get dataMoveToLocal => '將雲端資料移到此裝置';

  @override
  String get dataMoveToLocalConfirm => '系統會先複製並驗證資料，再從雲端刪除。完成後資料只有這台裝置、這個瀏覽器及目前的瀏覽器使用者設定檔看得到；換裝置、換瀏覽器或清除網站資料時不會自動出現，且可能永久遺失。確定繼續嗎？';

  @override
  String get dataMoveToLocalFailed => '部分資料無法搬移，雲端原始資料已保留。';

  @override
  String get dataMoveToLocalSuccess => '雲端資料已移到此裝置。';

  @override
  String get dateClear => '清除日期';

  @override
  String get days => '天';

  @override
  String get delete => '刪除';

  @override
  String get deleteError => '刪除失敗';

  @override
  String deleteNumberedItem(int number, String name) {
    return '要刪除第 $number 項「$name」嗎？';
  }

  @override
  String get deleteOk => '✅ 刪除完成';

  @override
  String get description => '描述';

  @override
  String get discardChanges => '捨棄變更';

  @override
  String get dislike => '不喜歡';

  @override
  String get downloaded => '✅ 已下載';

  @override
  String get edit => '編輯';

  @override
  String get email => '電子郵件';

  @override
  String get emailAlreadyInUse => '帳號已經被人註冊。';

  @override
  String get emailNotConfirmed => '帳號尚未驗證';

  @override
  String get emailRateLimitExceeded => '驗證信寄送次數過多，請稍後再試。';

  @override
  String get endDate => '結束日期';

  @override
  String get endsToday => '已經開始，今日結束';

  @override
  String get endTime => '結束時間';

  @override
  String get englishRpgAdventureTitle => '英文 RPG 冒險';

  @override
  String get enterAnswer => '請輸入答案';

  @override
  String get excelColumnHeaderActivityName => '活動名稱_______________________';

  @override
  String get excelColumnHeaderAgeMax => '最大年齡';

  @override
  String get excelColumnHeaderAgeMin => '最低年齡';

  @override
  String get excelColumnHeaderDescription => '描述______';

  @override
  String get excelColumnHeaderEndDate => '結束日期__';

  @override
  String get excelColumnHeaderEndTime => '結束時間';

  @override
  String get excelColumnHeaderFee => '費用';

  @override
  String get excelColumnHeaderId => '活動 id_______________________';

  @override
  String get excelColumnHeaderIsFree => '免費 ?';

  @override
  String get excelColumnHeaderIsOutdoor => '戶外 ?';

  @override
  String get excelColumnHeaderKeywords => '關鍵字_______________________';

  @override
  String get excelColumnHeaderMasterUrl => '活動網址_______________________';

  @override
  String get excelColumnHeaderPriceMax => '最高價格';

  @override
  String get excelColumnHeaderPriceMin => '最低價格';

  @override
  String get excelColumnHeaderSponsor => '相關單位';

  @override
  String get excelColumnHeaderStartDate => '開始日期__';

  @override
  String get excelColumnHeaderStartTime => '開始時間';

  @override
  String get externalLinkOpenFailed => '無法開啟連結，請稍後再試';

  @override
  String get fee => '費用';

  @override
  String get free => '免費';

  @override
  String get go => '前往';

  @override
  String get hint => '提示';

  @override
  String get indoor => '室內';

  @override
  String get invalidEmail => '帳號格式錯誤';

  @override
  String get isFree => '免費 ?';

  @override
  String get isOutdoor => '室外 ?';

  @override
  String get keywords => '關鍵字';

  @override
  String get like => '喜歡';

  @override
  String get loading => '載入中…';

  @override
  String get loadingSections => '正在載入章節…';

  @override
  String get manualEntry => '手動新增';

  @override
  String get masterUrl => '連結';

  @override
  String get month => '月';

  @override
  String get moreActions => '更多';

  @override
  String get networkError => '無法連線，請檢查網路後再試。';

  @override
  String get next => '下一題';

  @override
  String nextFreeHour(String startTime, String endTime) {
    return '今天 $startTime～$endTime 沒有行程';
  }

  @override
  String get nextMonth => '下一個月';

  @override
  String get noData => '沒有資料';

  @override
  String get noEmailError => '請輸入帳號';

  @override
  String get noInfoAvailable => '沒有資料';

  @override
  String get noPipes => '沒有可用管線';

  @override
  String get notFilled => '尚未填寫';

  @override
  String get notSupportUpload => '⚠️ 此平台尚未支援上傳';

  @override
  String ongoingUntil(String date) {
    return '進行中，至 $date';
  }

  @override
  String get openChatGPT => '開啟 ChatGPT';

  @override
  String get outdoor => '戶外';

  @override
  String get parsing => '解析';

  @override
  String get pay => '付費';

  @override
  String get postText => '貼上活動全文...';

  @override
  String get previous => '上一題';

  @override
  String get previousMonth => '上一個月';

  @override
  String priceEarningsRatio(String value) {
    return '本益比：$value';
  }

  @override
  String get priceMax => '最高價格';

  @override
  String get priceMin => '最低價格';

  @override
  String get publishedContentDeleteAdminOnly => '已公開資料僅限管理員刪除。您仍可編輯，儲存後會轉為待審核。';

  @override
  String get publishedSubmission => '已公開';

  @override
  String get publishedSubmissionTooltip => '已經公開此資訊，所有人均可閱覽。';

  @override
  String get registrationSuccessful => '註冊成功。';

  @override
  String relativeStrengthIndex(String value) {
    return '相對強弱指標：$value';
  }

  @override
  String get repeatOptions => '重複次數';

  @override
  String get repeatOptionsEvery => '每';

  @override
  String get repeatOptionsEveryDay => '每天';

  @override
  String get repeatOptionsEveryMonth => '每月';

  @override
  String get repeatOptionsEveryTwoMonths => '每兩個月';

  @override
  String get repeatOptionsEveryTwoWeeks => '每兩週';

  @override
  String get repeatOptionsEveryWeek => '每週';

  @override
  String get repeatOptionsEveryYear => '每年';

  @override
  String get repeatOptionsOnce => '僅一次';

  @override
  String get replacePhoto => '更換';

  @override
  String get requiredField => '此欄位不可空白';

  @override
  String get restart => '重新開始';

  @override
  String get retry => '重試';

  @override
  String get review => '審核';

  @override
  String get save => '儲存';

  @override
  String get scrambledWords => '要重新排列的單字';

  @override
  String get scrollThisArea => '在此區域上下滑動';

  @override
  String get search => '搜尋';

  @override
  String get searchKeywords => '關鍵字搜尋(逗點分隔)';

  @override
  String get secondaryCategoryLabel => '次分類';

  @override
  String get setAlarm => '設定鬧鐘';

  @override
  String get setAlarmCompleted => '✅ 設定鬧鐘完成';

  @override
  String get speak => '語音輸入';

  @override
  String get speakingText => '要朗讀的文字';

  @override
  String get speakingTitle => '口說練習';

  @override
  String get speakUp => '說出來';

  @override
  String get sponsor => '相關單位';

  @override
  String get startDate => '開始日期';

  @override
  String startsInDays(int count) {
    return '$count 天後開始';
  }

  @override
  String get startsToday => '今天開始';

  @override
  String get startsTomorrow => '明天開始';

  @override
  String get startTime => '開始時間';

  @override
  String get statusNotStarted => '尚未開始';

  @override
  String get subUrl => '連結';

  @override
  String get switchToList => '切換為清單';

  @override
  String get toBeDetermined => '待定';

  @override
  String get today => '今日';

  @override
  String get todayLifeOverview => '今日生活總覽';

  @override
  String get todayLifeOverviewHint => '行程、收支與積分集中整理，點選項目即可查看詳情';

  @override
  String get toggleView => '切換檢視模式';

  @override
  String get tooManyRequests => '操作過於頻繁，請稍後再試。';

  @override
  String get totalAmount => '總金額';

  @override
  String get twoOptionsRequired => '請至少輸入兩個答案選項';

  @override
  String get unableToLoadDocument => '無法載入這份文件。';

  @override
  String get unknownError => '未知的錯誤';

  @override
  String get unpublishedSubmission => '尚未公開';

  @override
  String get unpublishedSubmissionTooltip => '此資訊正在等待審核，目前只有你與管理者可以閱覽。';

  @override
  String get unsavedChangesPrompt => '變更尚未儲存，確定要捨棄嗎？';

  @override
  String get uploadExcel => '上傳 Csv';

  @override
  String get uploadFailed => '❌ 上傳失敗';

  @override
  String get uploadInProgress => '❌ 前次上傳尚在執行中';

  @override
  String get uploadSuccess => '✅ 上傳成功';

  @override
  String get url => '網址';

  @override
  String get weekDayFri => '五';

  @override
  String get weekDayMon => '一';

  @override
  String get weekDaySat => '六';

  @override
  String get weekDaySun => '日';

  @override
  String get weekDayThu => '四';

  @override
  String get weekDayTue => '二';

  @override
  String get weekDayWed => '三';

  @override
  String get wordSearchTitle => '單字搜尋';

  @override
  String get year => '年';

  @override
  String get accountSecurity => '帳號安全';

  @override
  String adminPasswordHelpBody(String account) {
    return '您好，我無法登入 Life Pilot，請協助處理密碼修改。\n\n帳號：$account\n\n管理員處理後，請回覆此信箱通知結果。';
  }

  @override
  String adminPasswordHelpEmailUnavailable(String email) {
    return '無法開啟郵件程式，請寄信至 $email。';
  }

  @override
  String get adminPasswordHelpOpened => '已開啟郵件程式，請確認內容後寄出。';

  @override
  String get adminPasswordHelpSubject => 'Life Pilot 密碼修改申請';

  @override
  String get adminPasswordResetDescription => '輸入求助者的帳號信箱，由系統產生臨時密碼。請回覆使用者，提醒登入後立即改成自己的密碼。';

  @override
  String get adminPasswordResetFailed => '無法建立臨時密碼，請稍後再試。';

  @override
  String get adminPasswordResetSend => '產生臨時密碼';

  @override
  String get adminPasswordResetTitle => '協助使用者重設密碼';

  @override
  String get adminPasswordResetUserEmail => '使用者信箱';

  @override
  String get adminPasswordResetUserNotFound => '找不到這個使用者帳號。';

  @override
  String get adminTemporaryPasswordCopied => '已複製臨時密碼。';

  @override
  String get adminTemporaryPasswordCopy => '複製臨時密碼';

  @override
  String adminTemporaryPasswordCreated(String email) {
    return '已為 $email 建立臨時密碼。';
  }

  @override
  String get adminTemporaryPasswordInstruction => '請複製後回覆給使用者，並提醒使用者登入後立即到「帳號安全」修改密碼。';

  @override
  String get adminTemporaryPasswordLabel => '臨時密碼';

  @override
  String get changePassword => '修改密碼';

  @override
  String get changePasswordFailed => '無法更新密碼，請確認目前密碼後再試一次。';

  @override
  String get changePasswordSuccessful => '密碼已更新。';

  @override
  String get confirmPassword => '確認密碼';

  @override
  String get currentPassword => '目前密碼';

  @override
  String get currentPasswordIncorrect => '目前密碼不正確。';

  @override
  String get hidePassword => '隱藏密碼';

  @override
  String get login => '  登入  ';

  @override
  String get loginAnonymously => '訪客登入';

  @override
  String get loginError => '登入失敗，請再試一次。';

  @override
  String get loginRelated => 'loginRelated';

  @override
  String get logout => '登出';

  @override
  String get logoutConfirmation => '確定要登出目前帳號嗎？';

  @override
  String get logoutError => '登出失敗，請再試一次。';

  @override
  String get moduleAuthorization => '模組授權';

  @override
  String get moduleAuthorizationDescription => '設定一般使用者可額外使用的功能。首頁與功能選單會同步套用。';

  @override
  String get moduleAuthorizationLoadFailed => '無法讀取模組授權，請確認帳號或稍後再試。';

  @override
  String get moduleAuthorizationNoAccess => '目前未開放額外功能。';

  @override
  String get moduleAuthorizationNotDeployed => '模組授權尚未部署，請先在 Supabase 執行授權 SQL。';

  @override
  String get moduleAuthorizationSaved => '模組授權已更新。';

  @override
  String get moduleAuthorizationSaveFailed => '授權未正確更新，請重新查詢後再試。';

  @override
  String get moduleAuthorizationSearchFirst => '請先輸入並查詢使用者 Email。';

  @override
  String get moduleAuthorizationUserNotFound => '找不到這個使用者帳號，請確認 Email。';

  @override
  String get newPassword => '新密碼';

  @override
  String get noPasswordError => '請輸入密碼';

  @override
  String get noRecoverySession => '系統找不到有效的「驗證憑證」或該憑證已經過期';

  @override
  String get password => '密碼';

  @override
  String get passwordDoesNotMeetPolicy => '新密碼不符合安全規則，請增加英文字母、數字或符號後再試。';

  @override
  String get passwordHelpDescription => '忘記目前密碼時，可以透過驗證信自行重設，或寄信請管理員協助。';

  @override
  String get passwordHelpTitle => '其他重設方式';

  @override
  String get passwordMismatch => '兩次輸入的密碼不一致。';

  @override
  String get passwordMustBeDifferent => '新密碼不可與目前密碼相同。';

  @override
  String get passwordReauthenticationRequired => '基於安全考量，請先使用信箱驗證重設密碼。';

  @override
  String get passwordRecoveryChoiceDescription => '請選擇透過驗證信自行重設，或寄信請管理員協助。';

  @override
  String get passwordRecoveryChoiceTitle => '選擇重設方式';

  @override
  String get passwordUpdateSuccessful => '密碼已更新，請使用新密碼登入。';

  @override
  String get register => '  註冊  ';

  @override
  String get registerError => '註冊失敗，請再試一次。';

  @override
  String get registrationVerificationRequired => '註冊成功，請前往信箱完成驗證後再登入。';

  @override
  String get resetByEmailVerification => '用驗證信重設';

  @override
  String get resetByEmailVerificationDescription => '系統會寄送安全連結，由你自行設定新密碼。';

  @override
  String get resetPassword => '重設密碼';

  @override
  String resetPasswordCooldown(int seconds) {
    return '$seconds 秒後可重寄';
  }

  @override
  String get resetPasswordEmail => '重設密碼信已寄出，請檢查信箱。';

  @override
  String get resetPasswordEmailNotFound => '帳號未註冊';

  @override
  String get resetPasswordError => '重設密碼失敗，請再試一次。';

  @override
  String get showPassword => '顯示密碼';

  @override
  String get updatePassword => '更新密碼';

  @override
  String get weakPassword => '密碼長度必須至少為 8 個字元';

  @override
  String get wrongUserPassword => '帳號密碼錯誤';

  @override
  String get dashboardLoadFailed => '資料載入失敗，請稍後再試';

  @override
  String get dashboardSettingSaveFailed => '設定儲存失敗，請稍後再試';

  @override
  String get home => '首頁';

  @override
  String get homeInsightDiscover => '今天還沒有行程，從感興趣的活動或景點開始安排吧';

  @override
  String get homeInsightReadyForReview => '今日行程已串連回憶、收支與積分，完成後可一次整理';

  @override
  String homeInsightResolveConflicts(int count) {
    return '今明兩天有 $count 個行程時間重疊，建議先調整安排。';
  }

  @override
  String homeInsightReviewOverdue(int count) {
    return '今天有 $count 個已結束行程尚未確認，別讓重要事情被遺漏。';
  }

  @override
  String get homeJourneyReviewHint => '完成行程時，可一次整理回憶、收支與積分';

  @override
  String get language => '語言';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => '英文';

  @override
  String get languageJapanese => '日文';

  @override
  String get languageKorean => '韓文';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get pageSelectorTooltip => '功能選單';

  @override
  String get settings => '設定';

  @override
  String get userMenuButton => '使用者選單';

  @override
  String get accountDeletionCloudOnly => '只有雲端模式可申請刪除帳號，請先將儲存位置切換為雲端。';

  @override
  String get adminPricingAccountingQuota => '記帳明細';

  @override
  String get adminPricingAnswerDays => '答題紀錄保留天數';

  @override
  String get adminPricingCalendarQuota => '行事曆筆數';

  @override
  String get adminPricingCreate => '建立新版本';

  @override
  String get adminPricingCreated => '新收費版本已建立；舊版本與既有使用者權益保持不變';

  @override
  String adminPricingCreateFailed(String error) {
    return '無法儲存收費版本：$error';
  }

  @override
  String adminPricingDeleteConfirmation(String name) {
    return '確定刪除 $name？只有未被任何訂閱或權益使用的版本才能刪除。';
  }

  @override
  String get adminPricingDeleted => '收費版本已刪除。';

  @override
  String get adminPricingDeleteInUse => '此收費版本仍被訂閱或權益使用，無法刪除。';

  @override
  String get adminPricingDeleteTitle => '刪除收費版本';

  @override
  String get adminPricingEffectiveDate => '生效日期';

  @override
  String get adminPricingGameQuota => '自建遊戲題目';

  @override
  String get adminPricingImageQuota => '圖片容量（MB）';

  @override
  String get adminPricingLocalZeroUnlimited => '本機 Plus 的額度欄位填 0 代表不限量。';

  @override
  String get adminPricingMemoryQuota => '回憶紀錄';

  @override
  String get adminPricingPointQuota => '積分明細';

  @override
  String get adminPricingQuarterlyPrice => '每季價格（TWD）';

  @override
  String get adminPricingRequired => '請填寫版本名稱與所有數字';

  @override
  String get adminPricingShareQuota => '行事曆分享人數';

  @override
  String get adminPricingSubtitle => '新版本只影響之後付款或加購的權益';

  @override
  String get adminPricingTitle => '建立使用者收費版本';

  @override
  String get adminPricingUpdate => '更新版本';

  @override
  String get adminPricingUpdated => '使用者收費版本已更新；既有訂閱權益快照不受影響';

  @override
  String get adminPricingVersionHint => '例如 2026-Q4';

  @override
  String get adminPricingVersionName => '版本名稱';

  @override
  String get adminSubscriptionAddQuota => '增加額度，不覆蓋尚未到期的權益';

  @override
  String get adminSubscriptionAddQuotaHint => '開啟後會將這筆新版額度與舊版額度相加';

  @override
  String get adminSubscriptionCloud => '雲端版';

  @override
  String get adminSubscriptionDeleteAll => '刪除全部訂閱與額度設定';

  @override
  String adminSubscriptionDeleteConfirmation(String email) {
    return '確定刪除 $email 的訂閱與額度設定嗎？使用者資料不會被刪除。';
  }

  @override
  String get adminSubscriptionDeleted => '訂閱與額度設定已刪除。';

  @override
  String adminSubscriptionDeleteEntitlementConfirmation(String version) {
    return '確定只刪除這一筆 $version 額度嗎？其他額度與使用者資料會保留。';
  }

  @override
  String get adminSubscriptionDeleteTitle => '刪除訂閱設定';

  @override
  String get adminSubscriptionEmail => '使用者 Email';

  @override
  String get adminSubscriptionEntitlementDeleted => '這一筆額度已刪除，其他額度仍保留。';

  @override
  String get adminSubscriptionEntitlements => '已建立的額度';

  @override
  String get adminSubscriptionExpiry => '本次權益到期日';

  @override
  String get adminSubscriptionExtend => '延長';

  @override
  String get adminSubscriptionExtend90Days => '延長 90 天';

  @override
  String get adminSubscriptionExtended => '訂閱期限已延長 90 天。';

  @override
  String adminSubscriptionExtendedDays(int days) {
    return '訂閱期限已延長 $days 天。';
  }

  @override
  String get adminSubscriptionExtensionDays => '延長天數';

  @override
  String get adminSubscriptionFree => '免費版';

  @override
  String get adminSubscriptionInactiveWarning => '連續 3 個月未新增或修改資料，帳號及雲端資料會自動清除。';

  @override
  String get adminSubscriptionInvalidExtensionDays => '請輸入 1 至 3650 的天數。';

  @override
  String get adminSubscriptionLoadedForEditing => '已載入目前訂閱，可修改後儲存。';

  @override
  String get adminSubscriptionLocal => '本機不限量';

  @override
  String get adminSubscriptionLookupRequired => '請先查詢資料';

  @override
  String get adminSubscriptionMultiplier => '購買額度倍率';

  @override
  String get adminSubscriptionNoExpiry => '免費版沒有到期日';

  @override
  String get adminSubscriptionNoPricing => '請先建立收費版本';

  @override
  String get adminSubscriptionNote => '補充說明';

  @override
  String get adminSubscriptionNotFound => '查無訂閱資料';

  @override
  String get adminSubscriptionNotFoundCreate => '可為此使用者建立新訂閱。';

  @override
  String get adminSubscriptionPaid => '付費版';

  @override
  String get adminSubscriptionPlan => '方案';

  @override
  String get adminSubscriptionPricingVersion => '收費版本';

  @override
  String get adminSubscriptionSave => '儲存訂閱設定';

  @override
  String get adminSubscriptionSaved => '使用者訂閱設定已儲存';

  @override
  String adminSubscriptionSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String get adminSubscriptionStoragePlan => '儲存方案';

  @override
  String get adminSubscriptionSubtitle => '套用付款當下的收費版本與額度';

  @override
  String adminSubscriptionTimes(int count) {
    return '$count 倍';
  }

  @override
  String get adminSubscriptionTitle => '管理使用者訂閱';

  @override
  String get adminSubscriptionUserNotFound => '找不到這個使用者帳號';

  @override
  String get adminVendorPricingCreated => '廠商收費版本已建立。';

  @override
  String get adminVendorPricingSubtitle => '未來付款使用最新生效版本；已購買權益保留當時快照。';

  @override
  String get adminVendorPricingTitle => '建立廠商收費版本';

  @override
  String get adminVendorPricingUpdated => '廠商收費版本已更新。';

  @override
  String get adminVendorSubscriptionSaved => '廠商訂閱已儲存。';

  @override
  String get adminVendorSubscriptionSubtitle => '指定廠商帳號的收費版本、額度倍數與到期日。';

  @override
  String get adminVendorSubscriptionTitle => '管理廠商訂閱';

  @override
  String get calendarInvitationQuotaExceeded => '已達行事曆分享上限，請先停止分享或升級方案。';

  @override
  String get dataCleanupCloudExplanation => '請先確認目前雲端超額項目，再選擇只清超額或清除全部個人資料。';

  @override
  String get dataStorageCloud => '雲端';

  @override
  String get dataStorageCloudWarning => '雲端資料可跨裝置使用，並受到目前方案額度限制。';

  @override
  String get dataStorageLocal => '此裝置';

  @override
  String get dataStorageLocalPlanRequired => '請先完成本機 Plus 付款，並由管理者開通後再切換。';

  @override
  String get dataStorageLocalWarning => '本機資料只有這台裝置、這個瀏覽器及目前的瀏覽器使用者設定檔看得到。換裝置、換瀏覽器或換瀏覽器設定檔時不會自動出現；解除安裝 App、清除網站或瀏覽器資料可能永久遺失。資料在方案額度內時可移回雲端。';

  @override
  String get dataStorageTitle => '儲存位置';

  @override
  String dataUploadQuotaExceeded(String resource, int used, int incoming, int quota) {
    return '已取消上傳：$resource 雲端目前已有 $used 筆，本次要上傳 $incoming 筆，但方案額度為 $quota 筆。';
  }

  @override
  String get dataUploadToCloud => '將本機資料上傳雲端（管理員）';

  @override
  String get dataUploadToCloudAction => '將本機資料移到雲端';

  @override
  String get dataUploadToCloudConfirm => '系統會先檢查全部本機資料是否符合目前方案額度。只有整批上傳並驗證成功後，才會刪除這台裝置的本機資料並切換為雲端模式；若超額或失敗則維持本機模式。確定繼續嗎？';

  @override
  String get dataUploadToCloudFailed => '部分本機資料無法上傳，已保留在這台裝置。';

  @override
  String get dataUploadToCloudSuccess => '本機資料已上傳雲端。';

  @override
  String get quotaFreePeriodActive => '目前生效中';

  @override
  String get quotaFreePeriodAutomaticHint => '只有設定的開始至結束時間內不限制新增容量。';

  @override
  String get quotaFreePeriodClear => '清除設定';

  @override
  String get quotaFreePeriodClearConfirm => '確定移除不限額度期間？移除後會立即恢復原方案額度。';

  @override
  String get quotaFreePeriodCleared => '不限額度活動已移除。';

  @override
  String get quotaFreePeriodDescription => '此期間新增的雲端資料不受方案額度限制；期間結束後自動恢復原方案額度。';

  @override
  String get quotaFreePeriodDisabled => '未啟用';

  @override
  String get quotaFreePeriodEdit => '修改期間';

  @override
  String get quotaFreePeriodEmpty => '尚未設定不限額度期間。';

  @override
  String get quotaFreePeriodEnabled => '啟用此期間';

  @override
  String get quotaFreePeriodEnd => '結束時間';

  @override
  String get quotaFreePeriodEnded => '已結束';

  @override
  String get quotaFreePeriodInvalidRange => '結束時間必須晚於開始時間。';

  @override
  String get quotaFreePeriodName => '活動名稱';

  @override
  String get quotaFreePeriodNew => '建立期間';

  @override
  String get quotaFreePeriodSaved => '不限額度活動已儲存。';

  @override
  String get quotaFreePeriodSaveFailed => '無法儲存不限額度活動。';

  @override
  String get quotaFreePeriodScheduled => '尚未開始';

  @override
  String get quotaFreePeriodStart => '開始時間';

  @override
  String get quotaFreePeriodTitle => '不限額度活動';

  @override
  String get quotaFreePeriodUnnamed => '未命名活動';

  @override
  String get recordCategoryAllowance => '補助';

  @override
  String get subscriptionActualQuotaTitle => '目前版本與實際額度';

  @override
  String subscriptionCloudVersionName(String version) {
    return '雲端 $version';
  }

  @override
  String get subscriptionCommonFeatures => '兩種方案皆可使用';

  @override
  String get subscriptionCommonFeaturesDetail => '行事曆、記帳、積分、推薦活動與景點，以及管理者遊戲題庫。本機資料不限量；股票與商業企劃書僅限管理者。';

  @override
  String get subscriptionCurrentAdmin => '目前權限：管理員（不限額度）';

  @override
  String get subscriptionCurrentCloudPlus => '目前方案：雲端 Plus';

  @override
  String get subscriptionCurrentFree => '目前方案：雲端免費版';

  @override
  String get subscriptionCurrentLocalPlus => '目前方案：本機 Plus';

  @override
  String get subscriptionCurrentPlus => '目前方案：Plus';

  @override
  String get subscriptionDeleteRecordHint => '刪除後會同步重新計算今日小計與總計。';

  @override
  String subscriptionDowngradeWarning(String date) {
    return '雲端資料已超過免費額度，請在 $date 前移轉或清除超額資料。';
  }

  @override
  String get subscriptionEffectiveDate => '生效日期';

  @override
  String get subscriptionFreeName => '雲端免費版';

  @override
  String get subscriptionFreePersonalRecords => '雲端保存：行事曆、記帳、積分、回憶各最多 30 筆';

  @override
  String get subscriptionFreePrice => '免費';

  @override
  String get subscriptionImagePlusOnly => '圖片上傳功能僅提供給 Plus 使用者。';

  @override
  String get subscriptionImageStorage => '圖片容量';

  @override
  String get subscriptionInactiveAccountWarning => '免費帳戶沒有到期日；若連續 3 個月沒有新增或修改資料，帳戶及雲端資料將由系統自動清除。';

  @override
  String get subscriptionLatestLocalVersionTitle => '下次付款適用的本機 Plus 版本';

  @override
  String get subscriptionLocalAnswerHistory => '本機答題紀錄不限量';

  @override
  String get subscriptionLocalPaidFeature => '此裝置上的紀錄與圖片不限量；資料不會自動出現在其他裝置';

  @override
  String get subscriptionLocalPaidName => '本機 Plus';

  @override
  String get subscriptionLocalPaidPrice => '每季 NT\$129';

  @override
  String subscriptionLocalUsage(int used) {
    return '此裝置已使用 $used 筆／不限量';
  }

  @override
  String subscriptionLocalVersionName(String version) {
    return '本機 $version';
  }

  @override
  String subscriptionNextCloudVersionName(String version) {
    return '下次付款適用：雲端 $version';
  }

  @override
  String get subscriptionNextCloudVersionTitle => '下次付款適用的雲端版本';

  @override
  String subscriptionNextLocalVersionName(String version) {
    return '下次付款適用：本機 $version';
  }

  @override
  String get subscriptionNextVersionTitle => '下次付款適用的最新版本';

  @override
  String subscriptionOverageItem(String resource, int used, int quota, int excess) {
    return '$resource：已用 $used／額度 $quota，超出 $excess';
  }

  @override
  String get subscriptionPlansTitle => '方案與訂閱';

  @override
  String get subscriptionPlusName => '雲端 Plus';

  @override
  String get subscriptionPlusPersonalRecords => '行事曆、記帳、積分、回憶各 300 筆雲端資料';

  @override
  String get subscriptionPlusPrice => '每季 NT\$129 起';

  @override
  String get subscriptionPricingVersion => '目前版本';

  @override
  String get subscriptionPurchaseComingSoon => 'App 內訂閱即將開放';

  @override
  String get subscriptionPurchaseExplanation => '目前尚不能購買 Plus。商店付款功能上線後，此頁會顯示正式價格、續訂條款，以及購買、恢復購買與管理訂閱功能。';

  @override
  String get subscriptionQuarterlyPayment => '每季費用';

  @override
  String get subscriptionQuotaMultiplier => '額度倍率';

  @override
  String get subscriptionQuotaReached => '目前方案的資料額度已滿，請先刪除舊資料後再新增，或升級 Plus。';

  @override
  String subscriptionQuotaReachedDetail(int used, int quota, int remaining) {
    return '雲端額度已滿：目前已使用 $used／$quota 筆，還可新增 $remaining 筆。請先刪除舊資料、改存此裝置，或升級 Plus。';
  }

  @override
  String get subscriptionRenewalRequired => '付費期間已結束，雲端資料目前為唯讀。請續訂，或將全部雲端資料安全搬移到這台裝置。';

  @override
  String subscriptionUsage(int used, int quota) {
    return '已使用 $used／$quota';
  }

  @override
  String subscriptionValidUntil(String date) {
    return '有效期限至 $date';
  }

  @override
  String subscriptionVersionOffer(String version, String date, int price) {
    return '$version・$date 生效・每季 NT\$$price';
  }

  @override
  String get vendorContentQuotaReached => '有效刊登額度已滿，請移除尚未結束的資料，或升級廠商方案。';

  @override
  String get vendorImageQuotaReached => '廠商圖片額度已滿，請移除圖片或升級廠商方案。';

  @override
  String vendorPlanActivityQuota(int count) {
    return '有效活動最多 $count 筆';
  }

  @override
  String vendorPlanAttractionQuota(int count) {
    return '有效景點最多 $count 筆';
  }

  @override
  String vendorPlanImageQuota(int count) {
    return '圖片容量 $count MB';
  }

  @override
  String get vendorPricingActiveOnlyNote => '額度只計算尚未結束的內容；已過期內容不占有效刊登額度。';

  @override
  String get vendorPricingDescription => '可先免費使用，再依組織需求增加公開資料數與成效統計期間。';

  @override
  String get vendorPricingTitle => '合作廠商方案';

  @override
  String get vendorQuotaFullHint => '已有額度用完，請先升級方案或移除有效資料再新增。';

  @override
  String get vendorQuotaNearFullHint => '額度即將用完，建議投稿前先查看可用方案。';

  @override
  String vendorQuotaRemaining(int count, String suffix) {
    return '尚可使用 $count$suffix';
  }

  @override
  String get weatherClouds => '多雲';

  @override
  String get addToSchedule => '加入行程';

  @override
  String get calendarCancelAllShares => '取消全部分享';

  @override
  String get calendarCancelSingleShare => '取消分享這個事件';

  @override
  String get calendarInvitationAccept => '接受';

  @override
  String get calendarInvitationAccepted => '已接受';

  @override
  String get calendarInvitationAccountNotFound => '找不到這個帳號。';

  @override
  String get calendarInvitationDecline => '拒絕';

  @override
  String get calendarInvitationDeclined => '已拒絕';

  @override
  String get calendarInvitationDuplicate => '這些事件已經分享給此帳號。';

  @override
  String get calendarInvitationEventUnavailable => '選取的事件已不存在或無法分享，請重新整理後再選擇。';

  @override
  String get calendarInvitationFailed => '無法更新行事曆邀請。';

  @override
  String calendarInvitationFailedWithReason(String reason) {
    return '無法更新行事曆邀請：$reason';
  }

  @override
  String get calendarInvitationPending => '等待接受';

  @override
  String get calendarInvitationRevoke => '停止分享';

  @override
  String get calendarInvitationRevoked => '已停止分享';

  @override
  String get calendarInvitationSelfInvite => '不能邀請自己的帳號。';

  @override
  String get calendarInvitationSent => '邀請已送出。';

  @override
  String get calendarInvitationStateChanged => '邀請狀態已變更，請重新整理後再操作。';

  @override
  String get calendarInvite => '邀請查看者';

  @override
  String get calendarInviteHint => '輸入帳號 Email，多個帳號請用逗號或換行分隔';

  @override
  String get calendarNoShareableEvents => '目前沒有可分享的事件。';

  @override
  String get calendarNoSharedEvents => '目前沒有已分享的事件。';

  @override
  String get calendarReceivedInvitations => '接收區塊';

  @override
  String get calendarSearchEmail => 'Email';

  @override
  String get calendarSearchEvent => '事件';

  @override
  String get calendarSelectEventRequired => '請至少選擇一個要分享的事件。';

  @override
  String get calendarSentInvitations => '邀請區塊';

  @override
  String get calendarShareAllEvents => '分享全部事件';

  @override
  String calendarSharedBy(String account) {
    return '由 $account 分享';
  }

  @override
  String get calendarSharedReadOnly => '共用行事曆・只能查看';

  @override
  String get calendarShareEvents => '選擇要分享的事件';

  @override
  String get calendarSharing => '共用行事曆';

  @override
  String get calendarSharingUpdated => '共用行事曆已更新。';

  @override
  String get calendarStopReceiving => '停止查看';

  @override
  String get eventReminder => '活動提醒';

  @override
  String get eventReminderDesc => '提醒你即將開始的活動';

  @override
  String get eventReminderToday => '今日活動提醒';

  @override
  String get pagCalendar => 'pagCalendar';

  @override
  String get reminderOptions => '提醒時間';

  @override
  String get reminderOptions15MinutesBefore => '15分鐘前';

  @override
  String get reminderOptions30MinutesBefore => '30分鐘前';

  @override
  String get reminderOptionsDefaultDayBefore8am => '前1天早上8點';

  @override
  String get reminderOptionsDefaultSameDay8am => '當天早上8點';

  @override
  String get reminderOptionsOneHourBefore => '1小時前';

  @override
  String get reminderOptionsOneMonthBefore => '1個月前';

  @override
  String get reminderOptionsOneWeekBefore => '1週前';

  @override
  String get reminderOptionsTwoDaysBefore => '2天前';

  @override
  String get reminderOptionsTwoWeeksBefore => '2週前';

  @override
  String get scheduleAlreadyStarted => '行程已開始';

  @override
  String get scheduleAwaitingReview => '待確認行程';

  @override
  String scheduleConflictBeforeSave(int count, String details) {
    return '此時段與 $count 個未完成行程重疊：\n$details\n仍要儲存嗎？';
  }

  @override
  String scheduleConflictCount(int count) {
    return '今明日有 $count 組行程時間重疊';
  }

  @override
  String scheduleConflictToday(int count) {
    return '今天有 $count 組行程時間重疊';
  }

  @override
  String scheduleConflictTomorrow(int count) {
    return '明天有 $count 組行程時間重疊';
  }

  @override
  String get scheduleDuplicateConfirmation => '此項目已在行事曆中，仍要再次加入嗎？';

  @override
  String get scheduleNeedsReview => '行程已結束，記得確認是否完成';

  @override
  String scheduleNeedsReviewCount(int count) {
    return '有 $count 個行程待確認';
  }

  @override
  String scheduleStartsInHours(int count) {
    return '$count 小時後開始';
  }

  @override
  String scheduleStartsInMinutes(int count) {
    return '$count 分鐘後開始';
  }

  @override
  String get todaySchedule => '今日行程';

  @override
  String tomorrowScheduleCount(int count) {
    return '明天有 $count 個行程';
  }

  @override
  String get upcomingSchedule => '近日行程';

  @override
  String viewRemainingSchedules(int count) {
    return '查看另外 $count 個行程';
  }

  @override
  String get attractionAddEdit => '新增／編輯景點';

  @override
  String get completeEventMessage => '完成後此行程會從今日列表消失';

  @override
  String get completeEventTitle => '完成行程';

  @override
  String get eventAdd => '新增活動';

  @override
  String get eventAdd1 => '行事曆新增活動';

  @override
  String get eventAddEdit => '新增／編輯活動';

  @override
  String get eventAddError => '要重複新增活動嗎';

  @override
  String get eventAddOk => '✅ 已新增活動';

  @override
  String get eventAddSub => '新增細項';

  @override
  String get eventAlreadyExists => '此活動已存在';

  @override
  String get eventCompleted => '行程已完成';

  @override
  String eventCompletedWithRecords(String items) {
    return '行程已完成：$items';
  }

  @override
  String get eventDelete => '刪除活動';

  @override
  String get eventExpense => '支出';

  @override
  String get eventIncome => '收入';

  @override
  String get eventRefresh => '更新推薦活動';

  @override
  String get eventRefreshFailed => '推薦活動更新失敗，請稍後再試。';

  @override
  String eventRefreshFailedSummary(int successful, int attempted, int failed) {
    return '更新未完成：共 $attempted 個來源，成功 $successful 個、失敗 $failed 個，請稍後再試。';
  }

  @override
  String get eventRefreshRunning => '推薦活動正在更新，請稍後再查看。';

  @override
  String get eventRefreshSucceeded => '推薦活動已更新。';

  @override
  String eventRefreshSucceededSummary(int successful, int attempted, int failed) {
    return '更新完成：共 $attempted 個來源，成功 $successful 個、失敗 $failed 個。';
  }

  @override
  String get eventSaved => '✅ 活動已儲存';

  @override
  String get eventSaveError => '活動名稱不可為空';

  @override
  String get eventSaveFailed => '活動儲存失敗，請稍後再試';

  @override
  String eventSessionCount(int count) {
    return '共 $count 個場次';
  }

  @override
  String get eventSub => '細項活動';

  @override
  String get findRecommendedEvent => '找推薦活動';

  @override
  String get findRecommendedPlace => '找推薦景點';

  @override
  String multiDayEvent(int count) {
    return '連續 $count 天';
  }

  @override
  String get noEventsToUpload => '❌ 沒有可上傳的活動';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get personalEvent => '行事曆';

  @override
  String get recommendEvent => '推薦活動';

  @override
  String get recommendEventZero => '目前沒有推薦活動';

  @override
  String get recommendPlaces => '推薦景點';

  @override
  String get recommendPlacesZero => '目前沒有推薦景點';

  @override
  String get vendorActiveActivities => '有效活動';

  @override
  String get vendorActiveAttractions => '有效景點';

  @override
  String vendorActivityAttractionMix(int activities, int attractions) {
    return '有效活動 $activities 筆・有效景點 $attractions 筆';
  }

  @override
  String get vendorActivityLabel => '活動';

  @override
  String get vendorAllActivities => '全部投稿';

  @override
  String get vendorAllShort => '全部';

  @override
  String get vendorAnalyticsCardClicks => '內容點擊';

  @override
  String get vendorAnalyticsDays => '成效統計天數';

  @override
  String vendorAnalyticsDescription(int days) {
    return '最近 $days 天，使用者與您的活動及景點互動成效。';
  }

  @override
  String get vendorAnalyticsDislikes => '不喜歡';

  @override
  String get vendorAnalyticsEmpty => '內容公開並產生瀏覽互動後，這裡會顯示成效資料。';

  @override
  String get vendorAnalyticsLikes => '喜歡';

  @override
  String get vendorAnalyticsPageViews => '頁面瀏覽';

  @override
  String get vendorAnalyticsRegistrationClicks => '報名點擊';

  @override
  String get vendorAnalyticsSaves => '收藏';

  @override
  String get vendorAnalyticsTitle => '成效統計';

  @override
  String get vendorAttractionLabel => '景點';

  @override
  String get vendorAttractionSubmissionGuideTitle => '讓更多人發現您的景點';

  @override
  String get vendorClickThroughRate => '瀏覽轉點擊';

  @override
  String get vendorContentMixTitle => '內容概況';

  @override
  String get vendorCreateAccountAction => '建帳號並投稿';

  @override
  String get vendorCreateAccountDescription => '建立帳號即可投稿活動、追蹤審核狀態，並持續維護公開資訊。';

  @override
  String get vendorCreateAccountTitle => '您是活動主辦單位？';

  @override
  String get vendorDashboardLoadFailed => '無法載入合作廠商資料。';

  @override
  String get vendorDashboardSubtitle => '管理投稿、追蹤審核並掌握目前額度。';

  @override
  String get vendorDashboardTitle => '合作廠商工作台';

  @override
  String get vendorManageActivities => '管理活動';

  @override
  String get vendorManageAttractions => '管理景點';

  @override
  String get vendorMineShort => '我的';

  @override
  String get vendorMySubmissions => '我的投稿';

  @override
  String get vendorNextStepClickMessage => '強化開頭說明、活動亮點及圖片，讓規劃者知道值得點開的原因。';

  @override
  String get vendorNextStepClickTitle => '把瀏覽轉成興趣';

  @override
  String get vendorNextStepExposureMessage => '清楚的名稱、封面圖片與城市，能讓使用者更快找到並理解內容。';

  @override
  String get vendorNextStepExposureTitle => '先建立清楚的第一印象';

  @override
  String get vendorNextStepFirstMessage => '先從一筆完整活動開始，填妥日期、地點、圖片與報名連結。';

  @override
  String get vendorNextStepFirstTitle => '刊登第一筆內容';

  @override
  String get vendorNextStepGrowingMessage => '持續更新日期與名額，再利用轉換率改善下一筆投稿。';

  @override
  String get vendorNextStepGrowingTitle => '內容已開始帶來行動';

  @override
  String get vendorNextStepRegistrationMessage => '請確認報名網址仍有效，且報名方式與行動提示足夠清楚。';

  @override
  String get vendorNextStepRegistrationTitle => '讓報名更順暢';

  @override
  String get vendorNextStepReviewMessage => '可在此追蹤結果；通過後，所有正在規劃行程的使用者都能發現。';

  @override
  String get vendorNextStepReviewTitle => '投稿正在審核中';

  @override
  String vendorPendingReviewCount(int count) {
    return '$count 筆投稿等待審核';
  }

  @override
  String get vendorPendingReviewHint => '審核進度集中顯示於此；通過後所有使用者都能看見。';

  @override
  String vendorPositiveActions(int count) {
    return '收藏與喜歡 $count 次';
  }

  @override
  String vendorPublishedPendingMix(int published, int pending) {
    return '已公開 $published 筆・待審核 $pending 筆';
  }

  @override
  String get vendorQualityCity => '城市';

  @override
  String get vendorQualityDate => '日期';

  @override
  String get vendorQualityDescription => '說明';

  @override
  String get vendorQualityLink => '報名連結';

  @override
  String get vendorQualityLocation => '地點';

  @override
  String get vendorQualityName => '標題';

  @override
  String vendorQualityProgress(int count, int total) {
    return '投稿完整度：$count／$total';
  }

  @override
  String vendorQuarterlyPrice(int price) {
    return '每季 NT\$$price';
  }

  @override
  String get vendorRecentSubmissionsEmpty => '尚未投稿，先新增第一筆活動或景點。';

  @override
  String get vendorRecentSubmissionsTitle => '近期投稿';

  @override
  String get vendorRegistrationAnalytics => '在同一工作區查看內容成效';

  @override
  String get vendorRegistrationDescription => '此帳號將開啟廠商工作台，專門管理活動、景點與審核狀態。';

  @override
  String get vendorRegistrationFreeStart => '可先使用免費廠商方案';

  @override
  String get vendorRegistrationRate => '點擊轉報名';

  @override
  String get vendorRegistrationTitle => '合作廠商帳號';

  @override
  String get vendorSubmissionBenefitManage => '自主管理資訊';

  @override
  String get vendorSubmissionBenefitReach => '觸及行程規劃者';

  @override
  String get vendorSubmissionBenefitReview => '審核狀態清楚';

  @override
  String get vendorSubmissionDescription => '讓正在安排生活的使用者看見您的活動與景點；公開後仍由原作者管理。';

  @override
  String get vendorSubmissionGuideDescription => '請填寫正確日期、地點、主辦單位與報名網址。審核後對所有人公開；後續修改會重新送審。';

  @override
  String get vendorSubmissionGuideTitle => '讓更多人發現您的活動';

  @override
  String get vendorSubmissionTitle => '投稿中心';

  @override
  String get vendorSubmitActivity => '投稿活動';

  @override
  String get vendorSubmitAttraction => '投稿景點';

  @override
  String get vendorSubmitShort => '投稿';

  @override
  String get vendorUntitledSubmission => '未命名投稿';

  @override
  String viewRemainingRecommendations(int count) {
    return '查看另外 $count 個推薦';
  }

  @override
  String get weekendEvent => '週末活動';

  @override
  String get city => '縣市';

  @override
  String get country => '國家';

  @override
  String get countryAustralia => '澳洲';

  @override
  String get countryCanada => '加拿大';

  @override
  String get countryChina => '中國';

  @override
  String get countryFrance => '法國';

  @override
  String get countryGermany => '德國';

  @override
  String get countryHongKong => '香港';

  @override
  String get countryIndia => '印度';

  @override
  String get countryIndonesia => '印尼';

  @override
  String get countryItaly => '義大利';

  @override
  String get countryJapan => '日本';

  @override
  String get countryMacau => '澳門';

  @override
  String get countryMalaysia => '馬來西亞';

  @override
  String get countryNetherlands => '荷蘭';

  @override
  String get countryNewZealand => '紐西蘭';

  @override
  String get countryPhilippines => '菲律賓';

  @override
  String get countrySingapore => '新加坡';

  @override
  String get countrySouthKorea => '韓國';

  @override
  String get countrySpain => '西班牙';

  @override
  String get countrySwitzerland => '瑞士';

  @override
  String get countryTaiwan => '台灣';

  @override
  String get countryThailand => '泰國';

  @override
  String get countryUnitedArabEmirates => '阿拉伯聯合大公國';

  @override
  String get countryUnitedKingdom => '英國';

  @override
  String get countryUnitedStates => '美國';

  @override
  String get countryVietnam => '越南';

  @override
  String get excelColumnHeaderCity => '縣市';

  @override
  String get excelColumnHeaderLocation => '地點____________________';

  @override
  String get location => '地點';

  @override
  String get mapCoordinateBackfill => '回填地圖座標';

  @override
  String get mapCoordinateBackfillFailed => '無法回填地圖座標，請稍後再試。';

  @override
  String mapCoordinateBackfillResult(int saved, int remaining, String coverage) {
    return '本次寫入 $saved 筆，剩餘 $remaining 筆，覆蓋率 $coverage%。';
  }

  @override
  String get openMap => '導航';

  @override
  String get selectCity => '選擇城市';

  @override
  String get switchToMap => '切換為地圖';

  @override
  String get weatherClear => '晴朗';

  @override
  String get weatherDrizzle => '毛毛雨';

  @override
  String get weatherForecast => '天氣預報';

  @override
  String get weatherMaximum => '最高';

  @override
  String get weatherMinimum => '最低';

  @override
  String get weatherMist => '霧霾';

  @override
  String get weatherRain => '雨';

  @override
  String get weatherSnow => '雪';

  @override
  String get weatherTemperature => '溫度';

  @override
  String get weatherThunderstorm => '雷雨';

  @override
  String get eventMemory => '回憶';

  @override
  String get memoryAdd => '新增回憶';

  @override
  String get memoryAddError => '要重複新增回憶嗎';

  @override
  String get memoryAddOk => '✅ 已新增回憶';

  @override
  String memoryCountForDay(int count) {
    return '$count 筆回憶';
  }

  @override
  String memoryCountForMonth(int count) {
    return '本月 $count 筆';
  }

  @override
  String memoryJourneySummary(int memoryCount, int dayCount, int cityCount) {
    return '目前載入 $memoryCount 段回憶，分布在 $dayCount 天、$cityCount 個城市';
  }

  @override
  String get memoryTrace => '回憶走廊';

  @override
  String get memoryTraceZero => '去創造更多回憶吧！';

  @override
  String get accountAlreadyExists => '帳戶已存在';

  @override
  String get accountCreate => '建立';

  @override
  String get accountDefault => '預設';

  @override
  String accountDeleteConfirmation(String name) {
    return '刪除 $name？';
  }

  @override
  String get accountingSpeechHint => '例如：加／扣金額';

  @override
  String get accountingUnit => '元';

  @override
  String get accountListEmpty => '尚未建立帳戶，請先建立帳戶後再選擇。';

  @override
  String get accountListLoadFailed => '帳戶清單載入失敗，請稍後再試';

  @override
  String get accountMaster => '總帳戶';

  @override
  String get accountName => '帳戶名稱';

  @override
  String get accountNew => '新增帳戶';

  @override
  String get accountPersonal => '個人';

  @override
  String get accountProject => '旅程';

  @override
  String get accountRecords => '記帳';

  @override
  String get accountSetMainCurrency => '設定主要幣別';

  @override
  String get accountSwitchCurrency => '切換幣別';

  @override
  String get currencyLabel => '幣別';

  @override
  String get editRecord => '編輯明細';

  @override
  String get homeInsightConnectAccounts => '選擇記帳與積分帳戶，完成行程時就能一次整理生活紀錄';

  @override
  String get quickAddAccounting => '快速記帳';

  @override
  String get recordAllCategories => '全部分類';

  @override
  String get recordCategoryArts => '美';

  @override
  String get recordCategoryBonus => '獎金';

  @override
  String get recordCategoryClothing => '衣';

  @override
  String get recordCategoryEducation => '育';

  @override
  String get recordCategoryEntertainment => '樂';

  @override
  String get recordCategoryFitness => '體';

  @override
  String get recordCategoryFood => '食';

  @override
  String get recordCategoryHousing => '住';

  @override
  String get recordCategoryIntelligence => '智';

  @override
  String get recordCategoryInvestmentIncome => '投資收入';

  @override
  String get recordCategoryOtherIncome => '其他收入';

  @override
  String get recordCategoryRefund => '退款';

  @override
  String get recordCategoryReserved => '保留項';

  @override
  String get recordCategorySalary => '薪資';

  @override
  String get recordCategoryTransportation => '行';

  @override
  String get recordCategoryUncategorized => '未分類';

  @override
  String get recordCategoryVirtue => '德';

  @override
  String get recordDate => '日期';

  @override
  String get recordNetChange => '淨變化';

  @override
  String get recordPleaseConfirm => '請確認';

  @override
  String get recordPrimaryCategory => '一級分類';

  @override
  String get recordSearchHint => '搜尋描述或次分類';

  @override
  String get recordSecondaryCategory => '二級分類（可留空）';

  @override
  String get recordSubmit => '送出';

  @override
  String get recordTime => '時間';

  @override
  String get recordTotal => '總計';

  @override
  String get recordValue => '數值';

  @override
  String get selectAccount => '選擇帳號';

  @override
  String get todayIncomeExpense => '今日收支';

  @override
  String get eventPointDecrease => '減分';

  @override
  String get eventPointIncrease => '加分';

  @override
  String get pointGroup => '團體';

  @override
  String get pointsRecord => '積分';

  @override
  String get pointsSpeechHint => '例如：加／扣積分';

  @override
  String get pointsUnit => '點';

  @override
  String get quickAddPoints => '快速記積分';

  @override
  String get todayPoints => '今日積分';

  @override
  String get totalPoints => '總積分';

  @override
  String get activeQuestion => '使用中';

  @override
  String get addQuestion => '新增題目';

  @override
  String get adminQuestionBank => '管理者題庫';

  @override
  String get allQuestionStatuses => '全部狀態';

  @override
  String get completedGrammarQuestion => '完整題目（請直接填入答案，例如 We are young）';

  @override
  String get customQuestionGroup => '＋自行建立分類';

  @override
  String get deactivateQuestion => '停用題目';

  @override
  String get duplicateQuestion => '相同的題目與答案已存在於你選擇的題目分類中。';

  @override
  String get editQuestion => '編輯題目';

  @override
  String get game => '遊戲';

  @override
  String get gameFailed => '未過關';

  @override
  String get gameLevel => '關卡';

  @override
  String get gameNoRecords => '尚無遊戲紀錄';

  @override
  String get gamePassed => '過關！';

  @override
  String gameProgressSummary(int passed, int total) {
    return '已通過 $passed／$total 關';
  }

  @override
  String gameRecentBestScore(String score) {
    return '近期最佳 $score';
  }

  @override
  String gameRecentPracticeSummary(int attempts, int passed) {
    return '近期練習 $attempts 次，通過 $passed 次';
  }

  @override
  String get gameScore => '分數';

  @override
  String gameScoreValue(num score) {
    return '得分：$score';
  }

  @override
  String get gameStart => '開始';

  @override
  String gameTitleScore(String game, num score) {
    return '$game（$score/100）';
  }

  @override
  String get grammarAnswerMustAppear => '完整題目中必須包含正確答案，系統才能自動建立填空位置。';

  @override
  String get grammarBaseWord => '單字原形（例如 head）';

  @override
  String get grammarQuestionHelp => '一般文法題請輸入包含答案的完整句子，例如 We are young，系統會自動把 are 變成空格。plural 分類只需輸入 head 與 heads。';

  @override
  String get inactiveQuestion => '已停用';

  @override
  String get japaneseTranslationQuestionHelp => '題目填日文，正確答案填翻譯。同一分類請至少建立 3 題。';

  @override
  String get koreanTranslationQuestionHelp => '題目填韓文，正確答案填翻譯。同一分類請至少建立 3 題。';

  @override
  String get leaveGameConfirmation => '確定要離開遊戲並返回上一頁嗎？';

  @override
  String get localQuestionBankOnly => '本機模式只使用此裝置的個人題庫，無法讀取管理者題庫。';

  @override
  String get monominoGameTitle => '單格拼圖';

  @override
  String get myQuestionBank => '我的題庫';

  @override
  String get myQuestionBankEmpty => '你的題庫在這個等級尚無可用題目，請先新增題目。';

  @override
  String get myQuestions => '我的題目';

  @override
  String get newQuestionGroup => '新分類名稱';

  @override
  String get noMyQuestions => '你尚未為這個遊戲新增題目。';

  @override
  String get polyominoGameTitle => '多格拼圖';

  @override
  String get puzzleMapTitle => '地圖拼圖';

  @override
  String get question => '題目';

  @override
  String get questionAdded => '題目已加入我的題庫';

  @override
  String get questionBank => '題庫來源';

  @override
  String get questionBankInsufficient => '目前題庫在這個關卡的可用題數不足。';

  @override
  String get questionDeactivated => '題目已停用。';

  @override
  String get questionDeleted => '題目已刪除';

  @override
  String get questionExample => '題目範例';

  @override
  String get questionGroup => '題目分類';

  @override
  String get questionGroupLevelNumber => '分類後面的 level 數字（留空代表 1）';

  @override
  String get questionGroupLevelRange => 'level 數字必須介於 1 到 30。';

  @override
  String get questionHasAnswersDeleteBlocked => '這個題目已有作答紀錄，無法刪除；你可以改為停用。';

  @override
  String get questionReactivated => '題目已重新啟用。';

  @override
  String get questionStatus => '題目狀態';

  @override
  String get questionStatusUpdateFailed => '題目狀態更新失敗，請稍後再試。';

  @override
  String get questionUpdated => '題目已更新';

  @override
  String get reactivateQuestion => '重新啟用題目';

  @override
  String get recordCategorySocial => '群';

  @override
  String get scratchGameTitle => 'Scratch 遊戲';

  @override
  String get scratchMazeTitle => 'Scratch 迷宮遊戲';

  @override
  String get sentenceOrWord => '完整單字或正確句子';

  @override
  String get sentenceQuestionHelp => '只要輸入完整單字或正確句子，例如 mother 或 I love apples，系統會自動拆開並建立重新排列題目。';

  @override
  String get socialTitle => '社交情境';

  @override
  String get speakingQuestionHelp => '請輸入使用者需要朗讀的單字或句子，例如 Nice to meet you。';

  @override
  String get threeQuestionsRequired => '目前題庫在這個關卡的可用題目合計至少需要 3 題。';

  @override
  String get translationQuestionHelp => '題目填原文，正確答案填翻譯。同一分類至少建立 3 題，遊戲才能產生兩個錯誤選項。';

  @override
  String get translationTitle => '翻譯';

  @override
  String get wordSearchQuestionHelp => '題目請填英文單字，正確答案填中文意思，例如 apple／蘋果。';

  @override
  String get wordSentenceBuilderTitle => '單字與句子組合';

  @override
  String get adminUserExistingPlans => '現有使用者收費版本';

  @override
  String get adminVendorExistingPlans => '現有收費版本';

  @override
  String get businessHours => '營業時間';

  @override
  String get businessPlan => '商業企劃書';

  @override
  String get dataCleanupLocalExplanation => '本機資料不限量，可清除這台裝置上的全部個人資料。';

  @override
  String get planTitle => '企劃書標題';

  @override
  String get selectTemplate => '選擇範本';

  @override
  String get untitledPlan => '未命名企劃書';

  @override
  String vendorCurrentPlan(String plan) {
    return '目前方案：$plan';
  }

  @override
  String vendorPlanAnalyticsDays(int count) {
    return '最近 $count 天成效統計';
  }

  @override
  String get vendorPlanCustomName => '自訂方案';

  @override
  String get vendorPlanFreeName => '免費方案';

  @override
  String get vendorPlanGrowthName => '成長方案';

  @override
  String get vendorPlanPartnerName => '合作方案';

  @override
  String get vendorViewPlans => '查看方案';

  @override
  String get stock => '股票';

  @override
  String stockClosingPrice(String value) {
    return '收盤價：$value';
  }

  @override
  String get stockDashboardTitle => '📊 市場儀表板';

  @override
  String get stockForeignBuy => '外資買超排行';

  @override
  String get stockForeignSell => '外資賣超排行';

  @override
  String get stockLoadFailed => '股票資料載入失敗，請稍後再試。';

  @override
  String get stockNet => '淨額';

  @override
  String get stockNoData => '目前沒有可顯示的股票資料。';

  @override
  String get stockRetry => '載入最新資料';

  @override
  String get stockSelectDate => '股票日期';

  @override
  String get stockThousandLots => '仟張';

  @override
  String stockTradingVolume(String value) {
    return '成交張數：$value';
  }

  @override
  String get stockUpdateFailed => '股票更新失敗，目前仍顯示上次可用的資料。';

  @override
  String get stockUpdateInProgress => '股票資料與模型更新中，完成後會自動顯示新結果。';

  @override
  String get stockUpdateSucceeded => '股票資料與模型更新完成。';

  @override
  String get feedback => '意見回饋';

  @override
  String get feedbackContent => '內容';

  @override
  String feedbackProcessedBy(String name, String time) {
    return '由 $name 於 $time 處理';
  }

  @override
  String get feedbackPurpose => '用途';

  @override
  String get feedbackRequired => '請填寫用途與內容。';

  @override
  String feedbackSendFailed(String error) {
    return '無法送出意見回饋：$error';
  }

  @override
  String get feedbackSent => '意見回饋已送出。';

  @override
  String get statusCompleted => '已完成';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusPending => '尚未處理';

  @override
  String get acceptLegalTermsRequired => '請先同意隱私權政策與服務條款，再進行註冊。';

  @override
  String get accountDeletionCancellationPending => '取消申請正在等待管理者確認。';

  @override
  String get accountDeletionCancellationSubmitted => '取消申請已送出，等待管理者確認。';

  @override
  String get accountDeletionCancelRequest => '取消申請';

  @override
  String get accountDeletionCompleted => '刪除申請已送出，等待管理者處理。';

  @override
  String get accountDeletionEmailUnavailable => '無法開啟電子郵件程式，請寄信至 minavi@alumni.nccu.edu.tw。';

  @override
  String accountDeletionFailed(Object message) {
    return '刪除帳號失敗：$message';
  }

  @override
  String get accountDeletionPending => '申請中';

  @override
  String get accountDeletionPendingDescription => '刪除帳號申請正在等待管理者處理。若不再刪除帳號，可以提出取消申請。';

  @override
  String get accountDeletionRequestDescription => '申請會送給管理者審核。管理者確認後才會刪除帳號與相關資料。';

  @override
  String get accountMenuAccountDeletion => '刪除帳號';

  @override
  String get accountMenuDataExport => '資料匯出';

  @override
  String get adminAccountDeletionCancellationConfirmed => '撤銷已確認，原刪除申請已清除。';

  @override
  String get adminAccountDeletionCancellationRequested => '使用者申請撤銷刪除帳號。';

  @override
  String get adminAccountDeletionCompleted => '帳號與相關資料已刪除。';

  @override
  String get adminAccountDeletionConfirmCancellation => '確認撤銷';

  @override
  String get agreeToLegalTermsPrefix => '我已閱讀並同意';

  @override
  String dataExportCompleted(Object path) {
    return '資料匯出完成：$path';
  }

  @override
  String get dataExportEmailUnavailable => '無法開啟電子郵件程式，請寄信至 minavi@alumni.nccu.edu.tw。';

  @override
  String dataExportFailed(Object message) {
    return '資料匯出失敗：$message';
  }

  @override
  String get dataExportIncludedPages => '下載內容包含：行事曆、回憶走廊、記帳與積分。';

  @override
  String get dataExportRequestDescription => '個人資料會直接下載為 Excel 檔案，包含雲端與本機資料。';

  @override
  String get dataExportSummarySheet => '匯出說明';

  @override
  String get exportExcel => '匯出 Excel';

  @override
  String get exportFailed => '❌ 匯出失敗';

  @override
  String get exportInProgress => '❌ 前次匯出尚在執行中';

  @override
  String get exportSuccess => '✅ 匯出成功';

  @override
  String get legalDocumentRead => '已讀';

  @override
  String get legalDocumentReadComplete => '已閱讀完畢';

  @override
  String get legalTermsConnector => '與';

  @override
  String get noEventsToExport => '❌ 沒有可匯出的活動';

  @override
  String get notSupportExport => '⚠️ 此平台尚未支援匯出';

  @override
  String get privacyPolicy => '隱私權政策';

  @override
  String get readLegalTermsRequired => '請先閱讀完隱私權政策與服務條款，再勾選同意。';

  @override
  String get requestAccountDeletion => '申請刪除帳號';

  @override
  String get requestDataExport => '申請匯出個人資料';

  @override
  String get termsOfService => '服務條款';
}
