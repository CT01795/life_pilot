import 'package:intl/intl.dart';

/// View formatting only. Reuses one locale's private formatters, never stock
/// records, account data or formatted values. Business rules stay in Model.
class StockDisplayFormats {
  StockDisplayFormats._(this.locale);
  final String locale;
  static StockDisplayFormats? _current;

  factory StockDisplayFormats.forLocale(String locale) {
    final current = _current;
    if (current != null && current.locale == locale) return current;
    return _current = StockDisplayFormats._(locale);
  }

  late final _quantity = NumberFormat('#,##0', locale);
  late final _price = NumberFormat('#,##0.00', locale);
  late final _date = DateFormat('yyyy/MM/dd', locale);

  // Missing quantities are not zero; show a placeholder rather than throwing
  // from NumberFormat when a partially populated futures row is displayed.
  String quantity(num? value) => value == null ? '—' : _quantity.format(value);
  String price(num value) => _price.format(value);
  String date(DateTime value) => _date.format(value);
}
