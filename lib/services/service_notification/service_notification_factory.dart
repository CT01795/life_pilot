import 'package:flutter/foundation.dart';
import 'package:life_pilot/services/platforms/notification_mobile.dart';
import 'package:life_pilot/services/platforms/notification_web.dart';
import 'service_notification_platform.dart';

ServiceNotificationPlatform? _instance;

// 取得目前使用的通知服務
ServiceNotificationPlatform getNotificationService() {
  // 若已存在實例，直接回傳
  if (_instance != null) return _instance!;

  // 根據平台建立對應實作
  if (kIsWeb) {
    _instance = NotificationServiceWeb();
  } else {
    _instance = NotificationServiceMobile();
  }
  return _instance!;
}

// 可手動注入（例如測試時注入 Stub）
void setNotificationService(ServiceNotificationPlatform service) {
  _instance = service;
}

// 清除目前注入（例如重新初始化時使用）
void resetNotificationService() {
  _instance = null;
}

