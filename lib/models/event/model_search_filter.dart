import 'package:life_pilot/core/const.dart';

class SearchFilter {
  String keywords;
  DateTime? startDate;
  DateTime? endDate;

  SearchFilter({
    this.keywords = constEmpty,
    this.startDate,
    this.endDate,
  });

  void clear() {
    keywords = constEmpty;
    startDate = null;
    endDate = null;
  }
}
