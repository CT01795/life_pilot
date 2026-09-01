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
  String resetPasswordCooldown(int seconds) {
    return '$seconds秒後に再送信できます';
  }

  @override
  String get noEmailError => 'メールアドレスを入力してください';

  @override
  String get invalidEmail => 'メールアドレスの形式が正しくありません';

  @override
  String get noPasswordError => 'パスワードを入力してください';

  @override
  String get noRecoverySession => 'システムは有効な「検証用資格情報」を見つけられないか、その資格情報の有効期限が切れています';

  @override
  String get resetPasswordError => 'パスワードのリセットに失敗しました。もう一度お試しください。';

  @override
  String get resetPasswordEmailNotFound => '登録されていないメールアドレスです';

  @override
  String get wrongUserPassword => 'メールかパスワードが正しくありません';

  @override
  String get emailNotConfirmed => 'メールアドレスが確認されていません';

  @override
  String get tooManyRequests => '操作が多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get emailRateLimitExceeded => '確認メールの送信回数が多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get networkError => '接続できません。ネットワークを確認してもう一度お試しください。';

  @override
  String get email => 'メールアドレス';

  @override
  String get password => 'パスワード';

  @override
  String get register => '  登録  ';

  @override
  String get updatePassword => 'パスワード更新';

  @override
  String get leaveGameConfirmation => 'ゲームを終了して前のページに戻りますか？';

  @override
  String get questionBank => '問題集';

  @override
  String get adminQuestionBank => '管理者の問題集';

  @override
  String get myQuestionBank => '自分の問題集';

  @override
  String get addQuestion => '問題を追加';

  @override
  String get question => '問題';

  @override
  String get correctAnswer => '正解';

  @override
  String get questionGroup => '問題グループ';

  @override
  String get answerOptions => '回答選択肢';

  @override
  String get answerOptionsHint => '選択肢はカンマで区切ってください';

  @override
  String get scrambledWords => '並べ替える単語';

  @override
  String get speakingText => '読み上げるテキスト';

  @override
  String get requiredField => '必須項目です';

  @override
  String get twoOptionsRequired => '回答選択肢を2つ以上入力してください';

  @override
  String get questionAdded => '問題を自分の問題集に追加しました';

  @override
  String get grammarQuestionHelp => '一般文法では We are young のような完成した文を入力すると、are が自動的に空欄になります。plural カテゴリーでは head と heads だけを入力します。';

  @override
  String get sentenceQuestionHelp => 'mother や I love apples のように、完成した単語または正しい文だけを入力してください。並べ替え形式に自動変換されます。';

  @override
  String get grammarBaseWord => '単語の原形（例：head）';

  @override
  String get completedGrammarQuestion => '答えを含む完成した問題（例：We are young）';

  @override
  String get grammarAnswerMustAppear => '空欄を自動作成するため、完成した問題に正解を含めてください。';

  @override
  String get questionExample => '問題の例';

  @override
  String get answerExample => '答えの例';

  @override
  String get sentenceOrWord => '完成した単語または正しい文';

  @override
  String get customQuestionGroup => '＋新しいカテゴリーを作成';

  @override
  String get newQuestionGroup => '新しいカテゴリー名';

  @override
  String get questionGroupLevelNumber => 'カテゴリー末尾の level 数字（空欄は 1）';

  @override
  String get questionGroupLevelRange => 'level 数字は 1 から 30 の範囲で入力してください。';

  @override
  String get speakingQuestionHelp => '読み上げる単語または文を入力してください。例：Nice to meet you。';

  @override
  String get translationQuestionHelp => '問題に原文、正解に翻訳を入力します。同じグループに3問以上作成すると、誤答を2つ生成できます。';

  @override
  String get japaneseTranslationQuestionHelp => '問題に日本語、正解に翻訳を入力します。同じグループに3問以上作成してください。';

  @override
  String get koreanTranslationQuestionHelp => '問題に韓国語、正解に翻訳を入力します。同じグループに3問以上作成してください。';

  @override
  String get wordSearchQuestionHelp => '問題に英単語、正解に意味を入力します。例：apple／りんご。';

  @override
  String get duplicateQuestion => '同じ問題と答えが選択した問題グループにすでに存在します。';

  @override
  String get myQuestionBankEmpty => 'このレベルで使用できる問題がありません。先に問題を追加してください。';

  @override
  String get threeQuestionsRequired => '自分の問題集で遊ぶには、作成した各グループに3問以上必要です。';

  @override
  String get myQuestions => '自分の問題';

  @override
  String get noMyQuestions => 'このゲームにはまだ問題を追加していません。';

  @override
  String get questionDeleted => '問題を削除しました';

  @override
  String get editQuestion => '問題を編集';

  @override
  String get questionUpdated => '問題を更新しました';

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
  String get weakPassword => 'パスワードは8文字以上で入力してください。';

  @override
  String get unknownError => '不明なエラーです';

  @override
  String get pageRelated => 'pageRelated';

  @override
  String get settings => '設定';

  @override
  String get pageSelectorTooltip => '機能メニュー';

  @override
  String get userMenuButton => 'ユーザー選択';

  @override
  String get home => 'ホーム';

  @override
  String get completeEventTitle => '旅程を完成させてください';

  @override
  String get completeEventMessage => '完了すると、この旅行は本日のリストから消えます。';

  @override
  String get noInfoAvailable => '利用可能な情報はありません。';

  @override
  String get openMap => 'ナビゲーション';

  @override
  String get selectCity => '都市を選択';

  @override
  String get selectAccount => 'アカウントを選択';

  @override
  String get personalEvent => '個人のイベント';

  @override
  String get stock => 'ストック';

  @override
  String get recommendEvent => 'おすすめイベント';

  @override
  String get recommendEventZero => '現在おすすめイベントはありません';

  @override
  String get recommendPlaces => 'おすすめの観光地';

  @override
  String get recommendPlacesZero => '現在、おすすめのスポットはありません';

  @override
  String get memoryTrace => '思い出の回廊';

  @override
  String get memoryTraceZero => 'さあ、思い出を追加しよう！';

  @override
  String get accountPersonal => '個人的';

  @override
  String get accountProject => '旅';

  @override
  String get pointGroup => 'グループ';

  @override
  String get stockSelectDate => '株価日付';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusNotStarted => '未開始';

  @override
  String get statusCompleted => '完了';

  @override
  String get statusPending => '未処理';

  @override
  String get noData => 'データがありません';

  @override
  String get accountMaster => 'グループ';

  @override
  String get accountRecords => '収支記録';

  @override
  String get todayIncomeExpense => '本日の収支';

  @override
  String get todayPoints => '今日のポイント';

  @override
  String get totalAmount => '合計金額';

  @override
  String get totalPoints => '合計ポイント';

  @override
  String get pointsRecord => 'ポイント記録';

  @override
  String get game => 'ゲーム';

  @override
  String get gameStart => '開始';

  @override
  String get gameNoRecords => 'ゲーム記録はありません';

  @override
  String get gameLevel => 'レベル';

  @override
  String get gameScore => 'スコア';

  @override
  String get ai => 'AIアシスタント';

  @override
  String get feedback => 'フィードバック';

  @override
  String get businessPlan => 'Business Plan';

  @override
  String get pageRecommendEvent => 'pageRecommendEvent';

  @override
  String get search => '検索';

  @override
  String get moreActions => 'その他';

  @override
  String get toggleView => '表示切り替え';

  @override
  String get exportExcel => 'Excelにエクスポート';

  @override
  String get eventAdd => 'イベントを追加';

  @override
  String get eventAdd1 => 'カレンダーにイベントを追加';

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
  String get uploadExcel => 'Csv にアップロード';

  @override
  String get uploadFailed => '❌ アップロードに失敗しました';

  @override
  String get uploadInProgress => '❌ 前回のファイルのアップロードはまだ進行中です。';

  @override
  String get uploadSuccess => '✅ アップロード成功';

  @override
  String get notSupportUpload => '⚠️ アップロードはサポートされていません';

  @override
  String get noEventsToUpload => '❌ アップロードするイベントはありません';

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
  String get excelColumnHeaderId => 'アクティビティ id_______________________';

  @override
  String get excelColumnHeaderMasterUrl => 'アクティビティ url_______________________';

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
  String get excelColumnHeaderAgeMin => '最低年齢';

  @override
  String get excelColumnHeaderAgeMax => '最大年齢';

  @override
  String get excelColumnHeaderIsFree => '無料 ?';

  @override
  String get excelColumnHeaderPriceMin => '最低価格';

  @override
  String get excelColumnHeaderPriceMax => '最高価格';

  @override
  String get excelColumnHeaderIsOutdoor => '屋外 ?';

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
  String get businessHours => '営業時間';

  @override
  String get endDate => '終了日';

  @override
  String get endTime => '終了時間';

  @override
  String get description => '説明';

  @override
  String get sponsor => '主催者';

  @override
  String get ageMin => '最低年齢';

  @override
  String get ageMax => '最大年齢';

  @override
  String get priceMin => '最低価格';

  @override
  String get priceMax => '最高価格';

  @override
  String get isFree => '無料 ？';

  @override
  String get isOutdoor => '屋外 ?';

  @override
  String get toBeDetermined => '未定';

  @override
  String get free => '無料';

  @override
  String get pay => '支払う';

  @override
  String get outdoor => '屋外';

  @override
  String get indoor => '屋内';

  @override
  String get masterUrl => 'リンク';

  @override
  String get subUrl => 'リンク';

  @override
  String get eventSaved => '✅ イベントを保存しました';

  @override
  String get eventSaveError => 'イベント名は空にできません';

  @override
  String get eventAlreadyExists => 'このイベントは既に存在します';

  @override
  String get eventSaveFailed => 'イベントを保存できませんでした。しばらくしてからもう一度お試しください';

  @override
  String get dashboardLoadFailed => '情報を読み込めませんでした。しばらくしてからもう一度お試しください';

  @override
  String get retry => '再試行';

  @override
  String get externalLinkOpenFailed => 'リンクを開けませんでした。しばらくしてからもう一度お試しください';

  @override
  String get dashboardSettingSaveFailed => '設定を保存できませんでした。しばらくしてからもう一度お試しください';

  @override
  String get accountListLoadFailed => 'アカウント一覧を読み込めませんでした。しばらくしてからもう一度お試しください';

  @override
  String get accountListEmpty => 'アカウントがまだ作成されていません。作成してから選択してください。';

  @override
  String get unsavedChangesPrompt => '変更が保存されていません。破棄しますか？';

  @override
  String get discardChanges => '変更を破棄';

  @override
  String get eventAddEdit => 'イベントの追加／編集';

  @override
  String get eventAddSub => 'サブ項目を追加';

  @override
  String get eventSub => 'サブイベント';

  @override
  String get save => '保存';

  @override
  String get searchKeywords => 'キーワード検索（カンマ区切り）';

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
  String get like => '好き';

  @override
  String get dislike => '嫌い';

  @override
  String get eventDelete => 'イベントを削除';

  @override
  String get deleteOk => '✅ 削除完了';

  @override
  String get deleteError => '削除失敗';

  @override
  String get todaySchedule => '本日の予定';

  @override
  String get upcomingSchedule => '今後の予定';

  @override
  String get addToSchedule => '旅程に追加する';

  @override
  String get clickHereToSeeMore => 'もっと見る';

  @override
  String get close => '閉じる';

  @override
  String get weatherForecast => '天気予報';

  @override
  String get weatherTemperature => '気温';

  @override
  String get weatherMinimum => '最低';

  @override
  String get weatherMaximum => '最高';

  @override
  String get weatherThunderstorm => '雷雨';

  @override
  String get weatherDrizzle => '霧雨';

  @override
  String get weatherRain => '雨';

  @override
  String get weatherSnow => '雪';

  @override
  String get weatherMist => '霧';

  @override
  String get weatherClear => '晴れ';

  @override
  String get weatherClouds => 'くもり';

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
  String get alarmUpdateFailed => 'リマインダーを設定できませんでした。しばらくしてからもう一度お試しください';

  @override
  String get previousMonth => '先月';

  @override
  String get today => '今日';

  @override
  String get nextMonth => '来月';

  @override
  String get postText => '全文を掲載してください';

  @override
  String get parsing => '解析する';

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
  String get repeatOptionsEveryTwoWeeks => '2週間ごと';

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

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get requestAccountDeletion => 'アカウント削除を申請';

  @override
  String get accountDeletionRequestDescription => 'アカウント削除申請用のメール下書きを開きます。アカウントとデータは直ちに削除されません。';

  @override
  String get continueLabel => '続行';

  @override
  String get accountDeletionEmailUnavailable => 'メールアプリを開けません。minavi@alumni.nccu.edu.tw までご連絡ください。';

  @override
  String get requestDataExport => '個人データのエクスポートを申請';

  @override
  String get dataExportRequestDescription => '個人データのエクスポート申請用のメール下書きを開きます。本人確認後、データを準備します。';

  @override
  String get dataExportEmailUnavailable => 'メールアプリを開けません。minavi@alumni.nccu.edu.tw までご連絡ください。';

  @override
  String get agreeToLegalTermsPrefix => '次の内容を読み、同意します：';

  @override
  String get acceptLegalTermsRequired => '登録する前に、プライバシーポリシーと利用規約に同意してください。';

  @override
  String get legalTermsConnector => 'と';

  @override
  String get accountMenuDataExport => 'データを出力';

  @override
  String get accountMenuAccountDeletion => 'アカウントを削除';

  @override
  String get readLegalTermsRequired => '同意する前に、プライバシーポリシーと利用規約を最後までお読みください。';

  @override
  String get legalDocumentReadComplete => '閲覧が完了しました';

  @override
  String get legalDocumentRead => '閲覧済み';

  @override
  String get registrationSuccessful => '登録が完了しました。';

  @override
  String get registrationVerificationRequired => '登録が完了しました。メール認証後にログインしてください。';

  @override
  String get confirmPassword => 'パスワードを確認';

  @override
  String get passwordMismatch => 'パスワードが一致しません。';

  @override
  String get showPassword => 'パスワードを表示';

  @override
  String get hidePassword => 'パスワードを非表示';

  @override
  String get passwordUpdateSuccessful => 'パスワードを更新しました。新しいパスワードでログインしてください。';

  @override
  String get stockUpdateInProgress => '株式データとモデルを更新しています。完了後、新しい結果が自動的に表示されます。';

  @override
  String get stockUpdateSucceeded => '株式データとモデルの更新が完了しました。';

  @override
  String get stockUpdateFailed => '株式データの更新に失敗しました。前回利用可能なデータを表示しています。';

  @override
  String get stockNoData => '現在表示できる株式データはありません。';

  @override
  String get stockLoadFailed => '株式データを読み込めませんでした。もう一度お試しください。';

  @override
  String get stockRetry => '最新データを読み込む';

  @override
  String get stockDashboardTitle => '📊 市場ダッシュボード';

  @override
  String get stockForeignBuy => '外国人投資家買い越しランキング';

  @override
  String get stockForeignSell => '外国人投資家売り越しランキング';

  @override
  String get stockThousandLots => '千ロット';

  @override
  String stockClosingPrice(String value) {
    return '終値：$value';
  }

  @override
  String stockTradingVolume(String value) {
    return '出来高：$valueロット';
  }

  @override
  String get editRecord => '明細を編集';

  @override
  String get recordDate => '日付';

  @override
  String get recordValue => '値';

  @override
  String get recordPrimaryCategory => 'カテゴリ';

  @override
  String get recordSecondaryCategory => 'サブカテゴリ（任意）';

  @override
  String get recordCategoryUncategorized => '未分類';

  @override
  String get recordCategoryReserved => '保持項目';

  @override
  String get recordCategoryFood => '食';

  @override
  String get recordCategoryClothing => '衣';

  @override
  String get recordCategoryHousing => '住';

  @override
  String get recordCategoryTransportation => '行';

  @override
  String get recordCategoryEducation => '育';

  @override
  String get recordCategoryEntertainment => '楽';

  @override
  String get recordCategoryVirtue => '徳';

  @override
  String get recordCategoryIntelligence => '智';

  @override
  String get recordCategoryFitness => '体';

  @override
  String get recordCategorySocial => '群';

  @override
  String get recordCategoryArts => '美';

  @override
  String get recordTotal => '合計';

  @override
  String get recordPleaseConfirm => '確認してください';

  @override
  String get recordSubmit => '送信';

  @override
  String get accountNew => '新しいアカウント';

  @override
  String get accountName => 'アカウント名';

  @override
  String get accountCreate => '作成';

  @override
  String get accountDefault => 'デフォルト';

  @override
  String get accountAlreadyExists => 'アカウントはすでに存在します';

  @override
  String accountDeleteConfirmation(String name) {
    return '$name を削除しますか？';
  }

  @override
  String get accountSetMainCurrency => '基準通貨を設定';

  @override
  String get accountSwitchCurrency => '通貨を切り替え';

  @override
  String get accountingSpeechHint => '例：金額を追加／減算';

  @override
  String get pointsSpeechHint => '例：ポイントを追加／減算';

  @override
  String get accountingUnit => '円';

  @override
  String get pointsUnit => 'ポイント';

  @override
  String get eventRefresh => 'おすすめイベントを更新';

  @override
  String get eventRefreshSucceeded => 'おすすめイベントを更新しました。';

  @override
  String get eventRefreshFailed => 'おすすめイベントを更新できませんでした。後でもう一度お試しください。';

  @override
  String get eventRefreshRunning => 'おすすめイベントを更新しています。しばらくしてからご確認ください。';

  @override
  String get questionHasAnswersDeleteBlocked => 'この問題には解答履歴があるため削除できません。代わりに無効化できます。';

  @override
  String get questionStatus => '問題の状態';

  @override
  String get allQuestionStatuses => 'すべての状態';

  @override
  String get activeQuestion => '使用中';

  @override
  String get inactiveQuestion => '無効';

  @override
  String get deactivateQuestion => '問題を無効化';

  @override
  String get reactivateQuestion => '問題を再有効化';

  @override
  String get questionDeactivated => '問題を無効化しました。';

  @override
  String get questionReactivated => '問題を再有効化しました。';

  @override
  String get questionStatusUpdateFailed => '問題の状態を更新できませんでした。もう一度お試しください。';

  @override
  String get mapCoordinateBackfill => '地図座標を補完';

  @override
  String get mapCoordinateBackfillFailed => '地図座標を補完できませんでした。後でもう一度お試しください。';

  @override
  String mapCoordinateBackfillResult(int saved, int remaining, String coverage) {
    return '$saved件を保存、残り$remaining件、カバー率$coverage%。';
  }

  @override
  String get calendarSharing => '共有カレンダー';

  @override
  String get calendarInvite => '閲覧者を招待';

  @override
  String get calendarInviteHint => 'メールをカンマまたは改行で区切って入力';

  @override
  String get calendarSentInvitations => '送信した招待';

  @override
  String get calendarReceivedInvitations => '受信した招待';

  @override
  String get calendarInvitationPending => '承認待ち';

  @override
  String get calendarInvitationAccepted => '承認済み';

  @override
  String get calendarInvitationDeclined => '拒否済み';

  @override
  String get calendarInvitationRevoked => '共有停止';

  @override
  String get calendarInvitationAccept => '承認';

  @override
  String get calendarInvitationDecline => '拒否';

  @override
  String get calendarInvitationRevoke => '共有を停止';

  @override
  String get calendarInvitationSent => '招待を送信しました。';

  @override
  String get calendarInvitationFailed => 'カレンダーの招待を更新できませんでした。';

  @override
  String calendarSharedBy(String account) {
    return '$account が共有';
  }

  @override
  String get calendarSharedReadOnly => '共有カレンダー・閲覧のみ';

  @override
  String get calendarShareEvents => '共有する予定を選択';

  @override
  String get calendarNoShareableEvents => '共有できる予定はありません。';

  @override
  String get calendarStopReceiving => '表示を停止';

  @override
  String get calendarShareAllEvents => 'すべての予定を共有';

  @override
  String get calendarNoSharedEvents => '現在共有中の予定はありません。';

  @override
  String get calendarCancelSingleShare => 'この予定の共有を停止';

  @override
  String get calendarCancelAllShares => 'すべての共有を停止';
}
