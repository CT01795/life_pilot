import 'dart:collection';

/// A read-only snapshot whose mapped values are built once, on first access.
/// Looking up length or checking emptiness does not run the mapper.
class LazyMappedList<S, T> extends ListBase<T> {
  LazyMappedList(Iterable<S> source, this._map)
    : _source = source is DeferredList<S>
          ? source.snapshot()
          : List<S>.of(source) {
    _values = List<T?>.filled(_source.length, null);
    _built = List<bool>.filled(_source.length, false);
  }

  final List<S> _source;
  final T Function(S) _map;
  late final List<T?> _values;
  late final List<bool> _built;

  @override
  int get length => _source.length;

  @override
  set length(int value) => throw UnsupportedError('Read-only mapped list');

  @override
  T operator [](int index) {
    RangeError.checkValidIndex(index, _source);
    if (!_built[index]) {
      _values[index] = _map(_source[index]);
      _built[index] = true;
    }
    return _values[index] as T;
  }

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('Read-only mapped list');
}

/// A growable list that decodes entries only when read. Mutations first obtain
/// an ordinary growable list, preserving the editing API used by event forms.
/// Snapshots share decoded objects, but not list membership, like List.of.
class DeferredList<T> extends ListBase<T> {
  DeferredList(Iterable<T Function()> loaders)
    : _entries = loaders.map(_DeferredEntry<T>.new).toList();

  DeferredList._(this._entries);

  final List<_DeferredEntry<T>> _entries;
  List<T>? _edited;

  DeferredList<T> snapshot() {
    final edited = _edited;
    return edited == null
        ? DeferredList<T>._(List.of(_entries))
        : DeferredList<T>(
            edited.map(
              (value) =>
                  () => value,
            ),
          );
  }

  List<T> get _writable => _edited ??= List<T>.generate(
    _entries.length,
    (index) => _entries[index].value,
  );

  @override
  int get length => _edited?.length ?? _entries.length;

  @override
  set length(int value) => _writable.length = value;

  @override
  T operator [](int index) =>
      _edited == null ? _entries[index].value : _edited![index];

  @override
  void operator []=(int index, T value) => _writable[index] = value;

  @override
  void add(T element) => _writable.add(element);

  @override
  void addAll(Iterable<T> iterable) => _writable.addAll(iterable);

  @override
  void insert(int index, T element) => _writable.insert(index, element);

  @override
  void insertAll(int index, Iterable<T> iterable) =>
      _writable.insertAll(index, iterable);
}

class _DeferredEntry<T> {
  _DeferredEntry(this._load);

  T Function()? _load;
  late T _value;

  T get value {
    final load = _load;
    if (load != null) {
      _value = load();
      _load = null;
    }
    return _value;
  }
}
