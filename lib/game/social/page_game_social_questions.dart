import 'package:flutter/material.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/social/page_game_social_question_create.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';

enum _StatusFilter { all, active, inactive }

class PageGameSocialQuestions extends StatefulWidget {
  const PageGameSocialQuestions({super.key});

  @override
  State<PageGameSocialQuestions> createState() => _PageState();
}

class _PageState extends State<PageGameSocialQuestions> {
  final _service = ServiceGame();
  final _searchController = TextEditingController();
  String _appliedKeyword = '';
  List<MySocialQuestion> _questions = const [];
  List<String> _categories = const [];
  final Set<String> _busyIds = {};
  int _totalCount = 0;
  int _generation = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _loaded = false;
  bool _loadError = false;
  String? _selectedCategory;
  _StatusFilter _status = _StatusFilter.all;

  bool get _hasMore => _questions.length < _totalCount;
  String get _statusValue => switch (_status) {
        _StatusFilter.all => 'all',
        _StatusFilter.active => 'active',
        _StatusFilter.inactive => 'inactive',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && (_loadingMore || !_hasMore)) return;
    final generation = append ? _generation : ++_generation;
    setState(() {
      append ? _loadingMore = true : _loading = true;
      if (!append) _loadError = false;
    });
    try {
      final pageFuture = _service.fetchMySocialQuestions(
        keyword: _appliedKeyword,
        category: _selectedCategory,
        status: _statusValue,
        offset: append ? _questions.length : 0,
      );
      final categoriesFuture = append
          ? Future.value(_categories)
          : _service.fetchMySocialQuestionCategories();
      final page = await pageFuture;
      final categories = await categoriesFuture;
      if (!mounted || generation != _generation) return;
      setState(() {
        _questions =
            append ? [..._questions, ...page.questions] : page.questions;
        _totalCount = page.totalCount;
        _categories = categories;
        _loaded = true;
      });
    } catch (error, stackTrace) {
      logger.e('Load Social questions failed',
          error: error, stackTrace: stackTrace);
      if (mounted && generation == _generation) {
        if (append || _loaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
          );
        } else {
          setState(() => _loadError = true);
        }
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _edit(MySocialQuestion question) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PageGameSocialQuestionCreate(existingQuestion: question),
      ),
    );
    if (mounted && changed == true) await _load();
  }

  Future<void> _add() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageGameSocialQuestionCreate(
          initialTitle: _appliedKeyword,
          initialCategory: _selectedCategory,
        ),
      ),
    );
    if (added == true && mounted) await _load();
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();
    setState(() => _appliedKeyword = _searchController.text.trim());
    _load();
  }

  Future<void> _toggle(MySocialQuestion question) async {
    final loc = AppLocalizations.of(context)!;
    final nextValue = !question.isActive;
    setState(() => _busyIds.add(question.id));
    try {
      await _service.setMySocialQuestionActive(
          id: question.id, isActive: nextValue);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(nextValue ? loc.questionReactivated : loc.questionDeactivated),
      ));
    } catch (error, stackTrace) {
      logger.e('Update Social status failed',
          error: error, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.questionStatusUpdateFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(question.id));
    }
  }

  Future<void> _delete(MySocialQuestion question) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(loc.confirmDelete),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc.delete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() => _busyIds.add(question.id));
    try {
      await _service.deleteMySocialQuestion(question.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(loc.questionDeleted)));
    } catch (error, stackTrace) {
      logger.e('Delete Social question failed',
          error: error, stackTrace: stackTrace);
      if (mounted) {
        final message = error is GameQuestionHasAnswersException
            ? loc.questionHasAnswersDeleteBlocked
            : loc.deleteError;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _busyIds.remove(question.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.myQuestions)),
      body: _loading && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _loadError && !_loaded
              ? Center(
                  child:
                      ElevatedButton(onPressed: _load, child: Text(loc.retry)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_loading) ...[
                        const LinearProgressIndicator(),
                        Gaps.h16,
                      ],
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: loc.searchKeywords,
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  tooltip: loc.clear,
                                  onPressed: _loading
                                      ? null
                                      : () {
                                          _searchController.clear();
                                          setState(() {
                                            _appliedKeyword = '';
                                          });
                                          _load();
                                        },
                                  icon: const Icon(Icons.clear),
                                ),
                              IconButton(
                                tooltip: loc.search,
                                onPressed: _loading ? null : _applySearch,
                                icon: const Icon(Icons.search),
                              ),
                            ],
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (!_loading) _applySearch();
                        },
                      ),
                      Gaps.h16,
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_selectedCategory),
                              initialValue: _selectedCategory,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: loc.questionGroup,
                                border: const OutlineInputBorder(),
                              ),
                              items: _categories
                                  .map((category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(category,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: _loading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedCategory = value);
                                      _load();
                                    },
                            ),
                          ),
                          if (_selectedCategory != null) ...[
                            Gaps.w8,
                            IconButton(
                              tooltip: loc.clear,
                              onPressed: _loading
                                  ? null
                                  : () {
                                      setState(() => _selectedCategory = null);
                                      _load();
                                    },
                              icon: const Icon(Icons.filter_alt_off),
                            ),
                          ],
                        ],
                      ),
                      Gaps.h16,
                      DropdownButtonFormField<_StatusFilter>(
                        initialValue: _status,
                        decoration: InputDecoration(
                          labelText: loc.questionStatus,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                              value: _StatusFilter.all,
                              child: Text(loc.allQuestionStatuses)),
                          DropdownMenuItem(
                              value: _StatusFilter.active,
                              child: Text(loc.activeQuestion)),
                          DropdownMenuItem(
                              value: _StatusFilter.inactive,
                              child: Text(loc.inactiveQuestion)),
                        ],
                        onChanged: _loading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _status = value);
                                  _load();
                                }
                              },
                      ),
                      Gaps.h16,
                      Text('${_questions.length} / $_totalCount'),
                      Gaps.h8,
                      if (_questions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Text(loc.noMyQuestions),
                              if (_appliedKeyword.isNotEmpty) ...[
                                Gaps.h16,
                                FilledButton.icon(
                                  onPressed: _loading ? null : _add,
                                  icon: const Icon(Icons.add),
                                  label: Text(loc.addQuestion),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ..._questions.map((question) => _card(question, loc)),
                      if (_hasMore)
                        Center(
                          child: TextButton(
                            onPressed:
                                _loadingMore ? null : () => _load(append: true),
                            child: _loadingMore
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(loc.clickHereToSeeMore),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _card(MySocialQuestion question, AppLocalizations loc) {
    final busy = _busyIds.contains(question.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(question.title),
        subtitle: Text(
          '${question.category}\n${question.scene}\n'
          '${loc.questionStatus}: '
          '${question.isActive ? loc.activeQuestion : loc.inactiveQuestion}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: busy
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: loc.edit,
                    onPressed: _loading ? null : () => _edit(question),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_loading,
                    onSelected: (action) => action == 'toggle'
                        ? _toggle(question)
                        : _delete(question),
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(question.isActive
                            ? loc.deactivateQuestion
                            : loc.reactivateQuestion),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(loc.delete)),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
