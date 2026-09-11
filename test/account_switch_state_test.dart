import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_pilot/accounting/controller_accounting_detail.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/model_accounting_account.dart';
import 'package:life_pilot/accounting/model_accounting_detail.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_business_plan.dart';
import 'package:life_pilot/business_plan/service_business_plan.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/point_record/controller_point_record_detail.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/point_record/model_point_record_account.dart';
import 'package:life_pilot/point_record/model_point_record_detail.dart';
import 'package:life_pilot/point_record/service_point_record.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_platform.dart';
import 'package:life_pilot/utils/service/service_weather.dart';

class _FakeAuth extends ControllerAuth {
  _FakeAuth(
    this.account, {
    this.admin = false,
    this.storage = DataStorageLocation.cloud,
  });

  String? account;
  bool admin;
  DataStorageLocation storage;

  @override
  String? get currentAccount => account;

  @override
  bool get isSysAdmin => admin;

  @override
  DataStorageLocation get preferredStorage => storage;

  void switchAccount(String value) {
    account = value;
    notifyListeners();
  }

  void switchStorage(DataStorageLocation value) {
    storage = value;
    notifyListeners();
  }
}

class _FakeNotificationService implements ServiceNotificationPlatform {
  @override
  FlutterLocalNotificationsPlugin? get plugin => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationResult> scheduleEventReminders({
    required EventItem event,
  }) async => NotificationResult(success: true);

  @override
  Future<void> cancelEventReminders({
    required String eventId,
    required List<CalendarReminderOption> reminderOptions,
  }) async {}

  @override
  Future<List<EventNotification>> getTodayEventNotifications({
    required List<EventItem> events,
    required String close,
  }) async => const [];
}

class _DelayedAccountingService extends ServiceAccounting {
  final response = Completer<List<ModelAccountingAccount>>();

  @override
  Future<List<ModelAccountingAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) => response.future;
}

class _DelayedPointService extends ServicePointRecord {
  final response = Completer<List<ModelPointRecordAccount>>();

  @override
  Future<List<ModelPointRecordAccount>> fetchAccounts({
    required String user,
    String? category,
    int? projectLimit,
    bool includeGraph = true,
  }) => response.future;
}

class _DelayedBusinessPlanService extends ServiceBusinessPlan {
  final response = Completer<List<ModelBusinessPlan>>();

  @override
  Future<List<ModelBusinessPlan>> fetchPlans({
    required String user,
    required DateTime dateFrom,
    required DateTime dateTo,
  }) => response.future;
}

class _DelayedAccountingDetailService extends ServiceAccounting {
  final response = Completer<List<ModelAccountingDetail>>();

  @override
  Future<List<ModelAccountingDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) => response.future;
}

class _DelayedPointDetailService extends ServicePointRecord {
  final response = Completer<List<ModelPointRecordDetail>>();

  @override
  Future<List<ModelPointRecordDetail>> fetchRecordsPage({
    required String accountId,
    required String type,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
    bool includeReservedRecords = true,
  }) => response.future;
}

class _DelayedEventService extends ServiceEvent {
  final response = Completer<List<EventItem>?>();

  @override
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
    int? limit,
    int offset = 0,
  }) => response.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'old accounting request cannot restore the previous user accounts',
    () async {
      final auth = _FakeAuth('old@example.com');
      final service = _DelayedAccountingService();
      final controller = ControllerAccountingList(service: service, auth: auth);

      final request = controller.loadAccounts();
      auth.account = 'new@example.com';
      controller.updateAuth(auth, notify: false);
      service.response.complete([
        ModelAccountingAccount(
          id: 'old',
          accountName: 'Old account',
          category: 'personal',
        ),
      ]);
      await request;

      expect(controller.accounts, isEmpty);
      expect(controller.isLoading, isFalse);
    },
  );

  test('old point request cannot restore the previous user accounts', () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedPointService();
    final controller = ControllerPointRecordList(service: service, auth: auth);

    final request = controller.loadAccounts();
    auth.account = 'new@example.com';
    controller.updateAuth(auth, notify: false);
    service.response.complete([
      ModelPointRecordAccount(
        id: 'old',
        accountName: 'Old account',
        category: 'personal',
      ),
    ]);
    await request;

    expect(controller.accounts, isEmpty);
    expect(controller.isLoading, isFalse);
  });

  test('account switch resets an admin-only selected page to home', () {
    final auth = _FakeAuth('admin@example.com', admin: true);
    final controller = ControllerPageMain(
      auth: auth,
      loc: lookupAppLocalizations(const Locale('zh')),
      initialLocale: const Locale('zh'),
    );

    controller.changePage(PageType.stock);
    expect(controller.selectedPage, PageType.stock);

    auth
      ..account = 'member@example.com'
      ..admin = false;
    controller.updateLocalization(
      lookupAppLocalizations(const Locale('zh')),
      const Locale('zh'),
      auth,
    );

    expect(controller.selectedPage, PageType.home);
    expect(controller.availablePages, isNot(contains(PageType.stock)));
    controller.dispose();
  });

  test(
    'old business plan request cannot restore the previous user plans',
    () async {
      final auth = _FakeAuth('old-admin@example.com', admin: true);
      final service = _DelayedBusinessPlanService();
      final controller = ControllerBusinessPlan(service: service, auth: auth);

      final request = controller.loadPlans();
      auth.account = 'new-admin@example.com';
      controller.updateAuth(auth, notify: false);
      service.response.complete([
        ModelBusinessPlan(
          id: 'old-plan',
          title: 'Old account plan',
          createdAt: DateTime.now(),
          sections: const [],
        ),
      ]);
      await request;

      expect(controller.plans, isEmpty);
      expect(controller.currentPlan, isNull);
      expect(controller.isPlansLoading, isFalse);
      controller.dispose();
    },
  );

  test('old accounting detail request is discarded after account switch',
      () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedAccountingDetailService();
    final controller = ControllerAccountingDetail(
      service: service,
      auth: auth,
      accountId: 'old-account-id',
    );

    final request = controller.loadToday();
    auth.account = 'new@example.com';
    controller.updateAuth(auth, notify: false);
    service.response.complete([
      ModelAccountingDetail(
        id: 'old-detail',
        accountId: 'old-account-id',
        createdAt: DateTime.now(),
        date: DateTime.now(),
        primaryCategory: 'food',
        description: 'Old record',
        type: 'balance',
        value: 100,
        currency: 'TWD',
      ),
    ]);
    await request;

    expect(controller.todayRecords, isEmpty);
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  test('old point detail request is discarded after account switch',
      () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedPointDetailService();
    final controller = ControllerPointRecordDetail(
      service: service,
      auth: auth,
      accountId: 'old-account-id',
    );

    final request = controller.loadToday();
    auth.account = 'new@example.com';
    controller.updateAuth(auth, notify: false);
    service.response.complete([
      ModelPointRecordDetail(
        id: 'old-detail',
        accountId: 'old-account-id',
        createdAt: DateTime.now(),
        date: DateTime.now(),
        primaryCategory: 'virtue',
        description: 'Old record',
        type: 'points',
        value: 10,
      ),
    ]);
    await request;

    expect(controller.todayRecords, isEmpty);
    expect(controller.isLoading, isFalse);
    controller.dispose();
  });

  test('old event request and visible data are cleared after account switch',
      () async {
    final auth = _FakeAuth('old@example.com');
    final service = _DelayedEventService();
    final model = ModelEvent()
      ..setEvents([EventItem(id: 'visible-old', name: 'Old visible event')]);
    final controller = ControllerEvent(
      auth: auth,
      serviceEvent: service,
      serviceWeather: ServiceWeather(),
      modelEvent: model,
      tableName: TableNames.memoryTrace,
    );
    final loc = lookupAppLocalizations(const Locale('zh'));

    final request = controller.loadEvents(isGetPublicEvents: false);
    auth.switchAccount('new@example.com');

    expect(controller.getFilteredEvents(loc), isEmpty);

    service.response.complete([
      EventItem(id: 'old-response', name: 'Old response event'),
    ]);
    await request;

    expect(controller.getFilteredEvents(loc), isEmpty);
    expect(controller.isLoadingEvents, isFalse);
    controller.dispose();
  });

  test('calendar cache is cleared when the same account changes storage', () {
    final auth = _FakeAuth(
      'member@example.com',
      storage: DataStorageLocation.cloud,
    );
    final model = ModelCalendar()
      ..setEvents([
        EventItem(
          id: 'cloud-event',
          name: 'Cloud event',
          startDate: DateTime(2026, 9, 1),
        ),
      ])
      ..cacheMonthEvents(
        DateTime(2026, 9),
        [
          EventItem(
            id: 'cached-cloud-event',
            name: 'Cached cloud event',
            startDate: DateTime(2026, 9, 2),
          ),
        ],
      );
    final controller = ControllerCalendar(
      modelCalendar: model,
      serviceEvent: ServiceEvent(),
      auth: auth,
      controllerNotification: ControllerNotification(
        service: _FakeNotificationService(),
      ),
      serviceWeather: ServiceWeather(),
      localeProvider: ProviderLocale(locale: const Locale('zh')),
      tableName: TableNames.calendarEvents,
      toTableName: TableNames.memoryTrace,
      closeText: 'Close',
    );

    auth.switchStorage(DataStorageLocation.local);
    controller.updateAuth(auth);

    expect(controller.events, isEmpty);
    expect(model.flatMonthEventsCache, isEmpty);
    expect(model.cachedEvents, isEmpty);
  });
}
