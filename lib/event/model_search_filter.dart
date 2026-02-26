class SearchFilter {
  String keywords;
  List<String> tags = [];
  DateTime? startDate;
  DateTime? endDate;

  SearchFilter({
    this.keywords = '',
    this.startDate,
    this.endDate,
  });

  void clear() {
    keywords = '';
    tags = [];
    startDate = null;
    endDate = null;
  }
}
