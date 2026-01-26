import 'package:life_pilot/core/const.dart';

class SearchFilter {
  String keywords;
  List<String> tags = [];
  DateTime? startDate;
  DateTime? endDate;

  SearchFilter({
    this.keywords = constEmpty,
    this.startDate,
    this.endDate,
  });

  void clear() {
    keywords = constEmpty;
    tags = [];
    startDate = null;
    endDate = null;
  }
}
