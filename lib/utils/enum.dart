enum AuthPage { login, register, pageMain }

enum PageType {
  personalEvent,
  stock,
  settings,
  recommendedEvent,
  recommendedAttractions,
  memoryTrace,
  accountRecords,
  pointsRecord,
  game,
  ai,
  feedbackAdmin,
  businessPlan,
}

enum AccountCategory {
  personal,
  project,
  master,
}

// ⏰ 提醒時間類型
enum CalendarReminderOption {
  fifteenMin,
  thirtyMin,
  oneHour,
  sameDay8am,
  dayBefore8am,
  twoDays,
  oneWeek,
  twoWeeks,
  oneMonth;
}

// 🔁 重複規則（事件重複頻率）
enum CalendarRepeatRule {
  once,
  everyDay,
  everyWeek,
  everyTwoWeeks,
  everyMonth,
  everyTwoMonths,
  everyYear,
}