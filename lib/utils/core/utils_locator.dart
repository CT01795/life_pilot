import 'dart:ui';

import 'package:get_it/get_it.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/controllers/controller_calendar.dart';
import 'package:life_pilot/providers/provider_locale.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_const.dart';

final getIt = GetIt.instance;

void setupLocator() {
  getIt.registerLazySingleton<ServiceStorage>(() => ServiceStorage());
  getIt.registerLazySingleton<ControllerAuth>(() => ControllerAuth());
  getIt.registerLazySingleton<ControllerCalendar>(
    () => ControllerCalendar(tableName: constTableCalendarEvents),
  );
  getIt.registerLazySingleton<ProviderLocale>(
      () => ProviderLocale(locale: Locale(constLocaleZh)));
}