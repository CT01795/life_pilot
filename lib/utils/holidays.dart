// -------------------- Calendar --------------------
// 🏮 節日工具類（用於連假判定）

class Holidays {
  // 📌 關鍵字：哪些節日要被合併成連假
  static const Set<String> mergeHolidayKeywords = {
    "春節",
    "兒童節",
    "清明節",
    "除夕",
    "New Year",
    "Children",
    "Tomb Sweeping",
    "New Year's Eve",
  };

  // ✅ 判斷是否屬於連假節日
  static bool shouldMergeHoliday(String summary) {
    return mergeHolidayKeywords.any((keyword) => summary.contains(keyword));
  }
}
