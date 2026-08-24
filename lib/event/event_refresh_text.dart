import 'package:flutter/widgets.dart';

class EventRefreshText {
  const EventRefreshText._();

  static String button(BuildContext context) => _localized(
        context,
        zh: '更新推薦活動',
        en: 'Update recommended events',
        ja: 'おすすめイベントを更新',
        ko: '추천 이벤트 업데이트',
      );

  static String succeeded(BuildContext context) => _localized(
        context,
        zh: '推薦活動已更新',
        en: 'Recommended events updated',
        ja: 'おすすめイベントを更新しました',
        ko: '추천 이벤트를 업데이트했습니다',
      );

  static String failed(BuildContext context) => _localized(
        context,
        zh: '推薦活動更新失敗，請稍後再試',
        en: 'Could not update recommended events. Try again later.',
        ja: 'おすすめイベントを更新できませんでした。後でもう一度お試しください。',
        ko: '추천 이벤트를 업데이트하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );

  static String _localized(
    BuildContext context, {
    required String zh,
    required String en,
    required String ja,
    required String ko,
  }) {
    switch (Localizations.localeOf(context).languageCode) {
      case 'ja':
        return ja;
      case 'ko':
        return ko;
      case 'zh':
        return zh;
      default:
        return en;
    }
  }
}
