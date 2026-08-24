import 'package:intl/intl.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';

class EventDeduplicationKey {
  const EventDeduplicationKey._();

  static String byName(EventItem event) {
    return _join([
      _normalizeName(event.name),
      _formatDate(event),
      _formatTime(event),
      EventCityNormalizer.normalize(event.city),
      _normalizeLocation(event.location),
    ]);
  }

  static String byId(EventItem event) {
    return _join([
      event.id.trim(),
      _formatDate(event),
      EventCityNormalizer.normalize(event.city),
      _normalizeLocation(event.location),
    ]);
  }

  static String bySource(EventItem event) {
    final masterUrl = event.masterUrl?.trim() ?? '';
    if (masterUrl.isEmpty) return '';
    return _join([
      masterUrl,
      _formatDate(event),
      _formatTime(event),
      EventCityNormalizer.normalize(event.city),
      _normalizeLocation(event.location),
    ]);
  }

  static String _normalizeName(String value) =>
      value.replaceAll(RegExp(r'[\s_]+'), '').toLowerCase();

  static String _normalizeLocation(String value) =>
      value.replaceAll('\u200B', '').trim().replaceAll('\u81FA', '\u53F0');

  static String _formatDate(EventItem event) =>
      DateFormat('yyyy-MM-dd').format(event.startDate!);

  static String _formatTime(EventItem event) {
    final time = event.startTime;
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  static String _join(List<String> parts) => parts.join('\u001F');
}
