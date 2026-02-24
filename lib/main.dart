import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/app/app_view.dart';
import 'package:life_pilot/config/config_app.dart';
import 'package:life_pilot/controllers/accounting/controller_accounting_account.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/controllers/calendar/controller_calendar.dart';
import 'package:life_pilot/controllers/calendar/controller_notification.dart';
import 'package:life_pilot/controllers/point_record/controller_point_record_account.dart';
import 'package:life_pilot/core/const.dart' as globals;
import 'package:life_pilot/models/event/model_event_calendar.dart';
import 'package:life_pilot/controllers/controller_page_main.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/auth/model_auth_view.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/event/service_speech.dart';
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';
import 'package:life_pilot/services/service_accounting.dart';
import 'package:life_pilot/services/service_business_plan.dart';
import 'package:life_pilot/services/service_notification/service_notification_factory.dart';
import 'package:life_pilot/services/service_permission.dart';
import 'package:life_pilot/services/service_point_record.dart';
import 'package:life_pilot/services/service_timezone.dart';
import 'package:life_pilot/services/service_weather.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/export/service_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 初始化時區
  CalendarConfig.tzLocation =
      await ServiceTimezone().setTimezoneFromDevice(); // ✅ 自動偵測並設定時區

  // ✅ 初始化 Firebase、Supabase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    debug: true, // 可選，用於除錯
  );

  final supabase = Supabase.instance.client;
  // ✅ 自動匿名登入，如果沒有 session 就登入
  if (supabase.auth.currentSession == null) {
    await supabase.auth.signInAnonymously();
  }

  globals.weatherApiKey = await ServiceEvent().getKey(keyName: "OPEN_WEATHER_API_KEY");

  // 只呼叫一次 NotificationService 的初始化
  final notificationService = getNotificationService();
  await notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<ControllerNotification>(
          create: (_) => ControllerNotification(service: notificationService),
        ),
        Provider<ServiceEvent>(
          create: (_) => ServiceEvent(),
        ),
        Provider<ModelEventCalendar>(
          create: (_) => ModelEventCalendar(),
        ),
        Provider<ServiceExportPlatform>(
          create: (_) => ServiceExportPlatformImpl(),
        ),
        Provider<ServiceExportExcel>(
          create: (_) => ServiceExportExcel(),
        ),
        ChangeNotifierProvider(
          create: (_) => ProviderLocale(locale: const Locale(Locales.zh)),
        ),
        ChangeNotifierProvider(
          create: (_) => ControllerAuth(),
        ),
        Provider<ServiceAccounting>(
          create: (_) => ServiceAccounting(Dio()),
        ),
        Provider<ServicePointRecord>(
          create: (_) => ServicePointRecord(Dio()),
        ),
        Provider<ServiceSpeech>(
          create: (_) => ServiceSpeech(),
        ),
        Provider(create: (_) => ServiceBusinessPlan()),
        ChangeNotifierProxyProvider<ControllerAuth, ControllerBusinessPlan>(
          create: (context) => ControllerBusinessPlan(
            service: context.read<ServiceBusinessPlan>(),
            auth: context.read<ControllerAuth>(),
          ),
          update: (_, auth, controller) {
            controller!.auth = auth;

            if (!controller.hasLoadedOnce) {
              controller.hasLoadedOnce = true;
              Future.microtask(() {
                controller.loadPlans();
              });
            }

            return controller;
          },
        ),
        ChangeNotifierProxyProvider2<ServiceAccounting, ControllerAuth,
            ControllerAccountingAccount>(
          create: (context) => ControllerAccountingAccount(
            service: context.read<ServiceAccounting>(),
            auth: context.read<ControllerAuth>(),
          ),
          update: (_, service, auth, controller) {
            controller ??= ControllerAccountingAccount(
              service: service,
              auth: auth,
            );
            controller.auth = auth;
            return controller;
          },
        ),
        ChangeNotifierProxyProvider2<ServicePointRecord, ControllerAuth,
            ControllerPointRecordAccount>(
          create: (context) => ControllerPointRecordAccount(
            service: context.read<ServicePointRecord>(),
            auth: context.read<ControllerAuth>(),
          ),
          update: (_, service, auth, controller) {
            controller ??= ControllerPointRecordAccount(
              service: service,
              auth: auth,
            );
            controller.auth = auth;
            return controller;
          },
        ),
        //-------------- Weather --------------
        Provider<ServiceWeather>(
          create: (_) => ServiceWeather(apiKey: globals.weatherApiKey),
        ),
        //-------------- ModelAuthView (ControllerAuth)--------------
        ChangeNotifierProxyProvider<ControllerAuth, ModelAuthView>(
          create: (context) => ModelAuthView(context.read<ControllerAuth>()),
          update: (_, auth, model) => model ?? ModelAuthView(auth),
        ),

        //-------------- ControllerCalendar (ModelCalendar, ControllerAuth, ServiceStorage, ProviderLocale)--------------
        ChangeNotifierProxyProvider5<
            ModelEventCalendar,
            ControllerAuth,
            ServiceEvent,
            ControllerNotification,
            ProviderLocale,
            ControllerCalendar>(
          create: (context) {
            final locale = context.read<ProviderLocale>().locale;
            final loc = lookupAppLocalizations(locale);
            return ControllerCalendar(
              modelEventCalendar: context.read<ModelEventCalendar>(),
              auth: context.read<ControllerAuth>(),
              serviceEvent: context.read<ServiceEvent>(),
              controllerNotification: context.read<ControllerNotification>(),
              servicePermission: ServicePermission(),
              localeProvider: context.read<ProviderLocale>(),
              tableName: TableNames.calendarEvents,
              toTableName: TableNames.memoryTrace,
              closeText: loc.close, // ✅ 使用當前語系
            );
          },
          update: (context, modelEventCalendar, auth, serviceEvent,
              notification, locale, controller) {
            controller ??= context.read<ControllerCalendar>();
            // ✅ 更新 controller 裡的依賴，而不是 new 一個
            controller
              ..auth = auth
              ..serviceEvent = serviceEvent
              ..controllerNotification = notification
              ..localeProvider = locale;
            // ✅ 更新 closeText
            controller
                .updateLocalization(lookupAppLocalizations(locale.locale));

            return controller;
          },
        ),

        //-------------- ControllerPageMain (ControllerAuth, ProviderLocale)--------------
        ChangeNotifierProxyProvider2<ControllerAuth, ProviderLocale,
            ControllerPageMain>(
          create: (context) {
            final locale = context.read<ProviderLocale>().locale;
            return ControllerPageMain(
              auth: context.read<ControllerAuth>(),
              loc: lookupAppLocalizations(locale), // ✅ 根據語系載入
              initialLocale: locale,
            );
          },
          update: (context, auth, localeProvider, controller) {
            final newLocale = localeProvider.locale;
            if (controller == null) {
              return ControllerPageMain(
                auth: auth,
                loc: lookupAppLocalizations(newLocale),
                initialLocale: newLocale,
              );
            } else {
              controller.updateLocalization(
                lookupAppLocalizations(newLocale),
                newLocale,
                auth,
              );
              return controller;
            }
          },
        ),
      ],
      child: const AppView(),
    ),
  );
}
