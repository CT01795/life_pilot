import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/accounting/service_accounting.dart';
import 'package:life_pilot/app/app_view.dart';
import 'package:life_pilot/app/config_app.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/calendar/controller_calendar.dart';
import 'package:life_pilot/calendar/controller_notification.dart';
import 'package:life_pilot/calendar/model_calendar.dart';
import 'package:life_pilot/event/model_event.dart';
import 'package:life_pilot/app/controller_page_main.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/event/service_event.dart';
import 'package:life_pilot/utils/service/export/service_export_excel.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:life_pilot/utils/service/service_notification/service_notification_factory.dart';
import 'package:life_pilot/utils/service/service_permission.dart';
import 'package:life_pilot/utils/service/service_weather.dart';
import 'package:provider/provider.dart';
import 'utils/service/export/service_export.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 只呼叫一次 NotificationService 的初始化
  final notificationService = getNotificationService();
  notificationService.initialize();

  runApp(
    MultiProvider(
      providers: [
        Provider<ControllerNotification>(
          create: (_) => ControllerNotification(service: notificationService),
        ),
        Provider<ServiceEvent>(
          create: (_) => ServiceEvent(),
        ),
        Provider<ModelCalendar>(
          create: (_) => ModelCalendar(),
        ),
        Provider<ModelEvent>(
          create: (_) => ModelEvent(),
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
        //-------------- Weather --------------
        Provider<ServiceWeather>(
          lazy: true,
          create: (_) => ServiceWeather(),
        ),
        //-------------- ModelAuthView (ControllerAuth)--------------
        ChangeNotifierProxyProvider<ControllerAuth, ModelAuthView>(
          create: (context) => ModelAuthView(context.read<ControllerAuth>()),
          update: (_, auth, model) => model ?? ModelAuthView(auth),
        ),
        //-------------- accounting--------------
        Provider<ServiceAccounting>(
          create: (_) => ServiceAccounting(),
        ),
        ChangeNotifierProxyProvider2<ServiceAccounting, ControllerAuth,
            ControllerAccountingList>(
          create: (context) => ControllerAccountingList(
            service: context.read<ServiceAccounting>(),
            auth: context.read<ControllerAuth>(),
          ),
          update: (_, service, auth, controller) {
            controller ??= ControllerAccountingList(
              service: service,
              auth: auth,
            );
            controller.auth = auth;
            return controller;
          },
        ),
        Provider(
          create: (_) => ServicePermission(),
        ),
        //-------------- ControllerCalendar (ModelCalendar, ControllerAuth, ServiceStorage, ProviderLocale)--------------
        ChangeNotifierProxyProvider6<
            ModelCalendar,
            ControllerAuth,
            ServiceEvent,
            ServiceWeather,
            ControllerNotification,
            ProviderLocale,
            ControllerCalendar>(
          create: (context) {
            final locale = context.read<ProviderLocale>().locale;
            final loc = lookupAppLocalizations(locale);
            return ControllerCalendar(
              modelCalendar: context.read<ModelCalendar>(),
              auth: context.read<ControllerAuth>(),
              serviceEvent: context.read<ServiceEvent>(),
              serviceWeather: context.read<ServiceWeather>(),
              controllerNotification: context.read<ControllerNotification>(),
              servicePermission: context.read<ServicePermission>(),
              localeProvider: context.read<ProviderLocale>(),
              tableName: TableNames.calendarEvents,
              toTableName: TableNames.memoryTrace,
              closeText: loc.close, // ✅ 使用當前語系
            );
          },
          update: (context, modelCalendar, auth, serviceEvent, serviceWeather, 
              notification, locale, controller) {
            controller ??= context.read<ControllerCalendar>();
            // ✅ 更新 controller 裡的依賴，而不是 new 一個
            controller.auth = auth;
            // ✅ 更新 closeText
            controller.updateLocalization(lookupAppLocalizations(locale.locale));

            return controller;
          },
        ),

        //-------------- ControllerPageMain (ControllerAuth, ProviderLocale)--------------
        ChangeNotifierProxyProvider2<ControllerAuth, ProviderLocale,
            ControllerPageMain>(
          create: (context) {
            final auth = context.read<ControllerAuth>();
            final locale = context.read<ProviderLocale>().locale;
            return ControllerPageMain(
              auth: auth,
              loc: lookupAppLocalizations(locale), // ✅ 根據語系載入
              initialLocale: locale,
            );
          },
          update: (context, auth, localeProvider, controller) {
            final newLocale = localeProvider.locale;
            controller ??= ControllerPageMain(
              auth: auth,
              loc: lookupAppLocalizations(newLocale),
              initialLocale: newLocale,
            );

            controller.updateLocalization(
              lookupAppLocalizations(newLocale),
              newLocale,
              auth,
            );
            return controller;
          },
        ),
      ],
      child: const AppView(),
    ),
  );
}
