import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Additional View-only filters, for example a city selected outside the list.
class PaginationScope extends InheritedWidget {
  const PaginationScope({super.key, required this.value, required super.child});
  final Object? value;
  @override
  bool updateShouldNotify(PaginationScope oldWidget) =>
      oldWidget.value != value;
}

/// Presentation state only: query cursors and permissions remain in Controllers.
class WidgetsLoadMore extends StatefulWidget {
  const WidgetsLoadMore({
    super.key,
    required this.hasMore,
    required this.count,
    required this.scope,
    required this.onLoadMore,
    this.owner,
    this.loading = false,
    this.error,
    this.enabled = true,
  });
  final bool hasMore, loading, enabled;
  final int count;
  final Object? scope, error;
  final Object? owner;
  final Future<void> Function() onLoadMore;
  @override
  State<WidgetsLoadMore> createState() => _WidgetsLoadMoreState();
}

class _WidgetsLoadMoreState extends State<WidgetsLoadMore> {
  // Lazy lists may recreate their footer at a different index. Retain only
  // presentation flags on the owning Controller, never records or cursors.
  static final _saved =
      Expando<({Object? scope, Object? outer, bool empty, bool probe})>();
  bool _busy = false, _empty = false, _probe = false;
  Object? _error;
  Object? _outerScope;
  bool _hasOuterScope = false;
  int _revision = 0;
  void _remember() {
    final owner = widget.owner;
    if (owner != null) {
      _saved[owner] = (
        scope: widget.scope,
        outer: _outerScope,
        empty: _empty,
        probe: _probe,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = context
        .dependOnInheritedWidgetOfExactType<PaginationScope>()
        ?.value;
    if (!_hasOuterScope && widget.owner != null) {
      final saved = _saved[widget.owner!];
      if (saved != null) {
        final same = saved.scope == widget.scope && saved.outer == outer;
        _empty = same && saved.empty;
        _probe = same ? saved.probe : true;
      }
    }
    if (_hasOuterScope && _outerScope != outer) {
      _revision++;
      _busy = false;
      _empty = false;
      _error = null;
      _probe = true;
    }
    _hasOuterScope = true;
    _outerScope = outer;
    _remember();
  }

  @override
  void didUpdateWidget(covariant WidgetsLoadMore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _revision++;
      _busy = false;
      _empty = false;
      _error = null;
      // Local filters can change without changing the server cursor.
      _probe = true;
    } else if (widget.count > oldWidget.count) {
      _empty = false;
    }
    _remember();
  }

  Future<void> _load() async {
    if (_busy || widget.loading || !widget.enabled) return;
    final revision = ++_revision, count = widget.count;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onLoadMore();
      if (!mounted || revision != _revision) return;
      // Allow the parent to publish the new count/error before comparing.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        setState(() {
          _busy = false;
          _probe = false;
          _empty = widget.error == null && widget.count <= count;
          _remember();
        });
      });
      setState(() {});
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final failed = _error != null || widget.error != null;
    final exhausted = !failed && (_empty || (!widget.hasMore && !_probe));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Center(
        child: _busy || widget.loading
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : exhausted
            ? Text(loc.noMoreData, textAlign: TextAlign.center)
            : TextButton(
                onPressed: widget.enabled ? _load : null,
                child: Text(failed ? loc.retry : loc.clickHereToSeeMore),
              ),
      ),
    );
  }
}
