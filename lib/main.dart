import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/firebase_options.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/notification/notification_entry.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/core/utils_timezone_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ 初始化時區
  constTzLocation = await setTimezoneFromDevice(); // ✅ 自動偵測並設定時區

  // ✅ 初始化 Firebase、Supabase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: constSupabaseUrl,
    anonKey: constSupabaseAnonKey,
  );

  // 只呼叫一次 NotificationService 的初始化
  await NotificationEntryImpl.initialize();

  setupLocator();

  runApp(const MyApp());
}

