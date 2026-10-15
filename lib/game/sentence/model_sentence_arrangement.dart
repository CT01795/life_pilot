import 'dart:collection';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';

/// Pure word/slot state. Moves preserve each word's identity and total count.
class ModelSentenceArrangement {
  final List<WordItem> _options = [];
  final List<WordItem?> _slots = [];
  final Map<String, int> _slotById = {};
  int _filled = 0;

  late final List<WordItem> options = UnmodifiableListView(_options);
  late final List<WordItem?> slots = UnmodifiableListView(_slots);
  bool get isComplete => _slots.isNotEmpty && _filled == _slots.length;

  void reset(Iterable<WordItem> words) {
    final snapshot = words.toList();
    if (snapshot.map((word) => word.id).toSet().length != snapshot.length) {
      throw ArgumentError('Word IDs must be unique');
    }
    _options
      ..clear()
      ..addAll(snapshot);
    _slots
      ..clear()
      ..addAll(List<WordItem?>.filled(snapshot.length, null));
    _slotById.clear();
    _filled = 0;
  }

  int? slotOf(WordItem word) => _slotById[word.id];

  bool canMoveTo(int target, WordItem word) =>
      target >= 0 &&
      target < _slots.length &&
      (_slotById.containsKey(word.id) ||
          _options.any((item) => item.id == word.id));

  bool moveTo(int target, WordItem word) {
    if (!canMoveTo(target, word)) return false;
    final source = _slotById[word.id];
    if (source == target) return false;
    final displaced = _slots[target];
    if (source != null) {
      _slots[target] = _slots[source];
      _slots[source] = displaced;
      if (displaced != null) _slotById[displaced.id] = source;
    } else {
      final bankIndex = _options.indexWhere((item) => item.id == word.id);
      // Use the model's canonical word, not an arbitrary drag payload.
      _slots[target] = _options.removeAt(bankIndex);
      if (displaced != null) {
        _options.add(displaced);
        _slotById.remove(displaced.id);
      } else {
        _filled++;
      }
    }
    _slotById[word.id] = target;
    return true;
  }

  bool removeAt(int index) {
    if (index < 0 || index >= _slots.length) return false;
    final word = _slots[index];
    if (word == null) return false;
    _options.add(word);
    _slots[index] = null;
    _slotById.remove(word.id);
    _filled--;
    return true;
  }
}
