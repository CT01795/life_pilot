import 'package:intl/intl.dart';

class ModelPointRecord {
  final String id;
  final String accountId;
  final DateTime createdAt;
  final String description;
  final String type;
  final int value;

  late final DateTime localTime;
  late final String displayTime;

  ModelPointRecord({
    required this.id,
    required this.accountId,
    required this.createdAt,
    required this.description,
    required this.type,
    required this.value,
  }){
    localTime = createdAt.toLocal();
    displayTime = _formatTime(localTime);
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    return time.year == now.year
        ? DateFormat('M/d HH:mm').format(time)
        : DateFormat('yyyy/M/d HH:mm').format(time);
  }
}