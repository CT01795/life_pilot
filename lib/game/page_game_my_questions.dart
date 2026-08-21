import 'package:flutter/material.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/page_game_question_create.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';

enum _QuestionStatusFilter { all, active, inactive }

class PageGameMyQuestions extends StatefulWidget {
  const PageGameMyQuestions({
    super.key,
    required this.gameName,
  });

  final String gameName;

  @override
  State<PageGameMyQuestions> createState() => _PageGameMyQuestionsState();
}

class _PageGameMyQuestionsState extends State<PageGameMyQuestions> {
  final ServiceGame _service = ServiceGame();
  List<MyGameQuestion> _questions = const [];
  List<String> _groups = const [];
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasLoaded = false;
  bool _hasError = false;
  int _loadGeneration = 0;
  final Set<String> _deletingIds = {};
  final Set<String> _updatingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGroup;
  _QuestionStatusFilter _statusFilter = _QuestionStatusFilter.all;

  bool get _hasMore => _questions.length < _totalCount;

  String get _statusValue => switch (_statusFilter) {
        _QuestionStatusFilter.all => 'all',
        _QuestionStatusFilter.active => 'active',
        _QuestionStatusFilter.inactive => 'inactive',
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
    if (!append && _isLoading && _hasLoaded) return;
    if (append && (_isLoadingMore || !_hasMore)) return;
    final generation = append ? _loadGeneration : ++_loadGeneration;
    setState(() {
      if (append) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _hasError = false;
      }
    });
    try {
      final pageFuture = _service.fetchMyQuestions(
        gameName: widget.gameName,
        keyword: _searchController.text,
        group: _selectedGroup,
        status: _statusValue,
        offset: append ? _questions.length : 0,
      );
      final groupsFuture = append
          ? Future.value(_groups)
          : _service.fetchMyQuestionGroupsForManagement(
              gameName: widget.gameName,
            );
      var page = await pageFuture;
      final groups = await groupsFuture;
      if (!mounted || generation != _loadGeneration) return;
      if (!append &&
          _selectedGroup != null &&
          !groups.contains(_selectedGroup)) {
        _selectedGroup = null;
        page = await _service.fetchMyQuestions(
          gameName: widget.gameName,
          keyword: _searchController.text,
          status: _statusValue,
        );
        if (!mounted || generation != _loadGeneration) return;
      }
      setState(() {
        _questions =
            append ? [..._questions, ...page.questions] : page.questions;
        _totalCount = page.totalCount;
        _groups = groups;
        _hasLoaded = true;
      });
    } catch (error, stackTrace) {
      logger.e(
        append
            ? 'Load more game questions failed'
            : 'Load game questions failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted && generation == _loadGeneration) {
        if (append || _hasLoaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
          );
        } else {
          setState(() => _hasError = true);
        }
      }
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _delete(MyGameQuestion question) async {
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

    setState(() => _deletingIds.add(question.id));
    try {
      await _service.deleteMyQuestion(
        gameName: widget.gameName,
        questionId: question.id,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.questionDeleted)),
      );
    } catch (error, stackTrace) {
      logger.e(
        'Delete game question failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        final message = error is GameQuestionHasAnswersException
            ? loc.questionHasAnswersDeleteBlocked
            : loc.deleteError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingIds.remove(question.id));
    }
  }

  Future<void> _edit(MyGameQuestion question) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PageGameQuestionCreate(
          gameName: widget.gameName,
          initialLevel: question.level,
          existingQuestion: question,
        ),
      ),
    );
    if (updated == true && mounted) await _load();
  }

  Future<void> _setActive(MyGameQuestion question, bool isActive) async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _updatingIds.add(question.id));
    try {
      await _service.setMyQuestionActive(
        gameName: widget.gameName,
        questionId: question.id,
        isActive: isActive,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive ? loc.questionReactivated : loc.questionDeactivated,
          ),
        ),
      );
    } catch (error, stackTrace) {
      logger.e(
        'Update game question status failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.questionStatusUpdateFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingIds.remove(question.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.myQuestions)),
      body: _isLoading && !_hasLoaded
          ? const Center(child: CircularProgressIndicator())
          : _hasError && !_hasLoaded
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(loc.unknownError),
                      Gaps.h8,
                      ElevatedButton(
                        onPressed: _load,
                        child: Text(loc.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_isLoading) ...[
                        const LinearProgressIndicator(),
                        Gaps.h16,
                      ],
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: loc.search,
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  tooltip: loc.clear,
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          _searchController.clear();
                                          setState(() {});
                                          _load();
                                        },
                                  icon: const Icon(Icons.clear),
                                ),
                              IconButton(
                                tooltip: loc.search,
                                onPressed: _isLoading ? null : _load,
                                icon: const Icon(Icons.search),
                              ),
                            ],
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (!_isLoading) _load();
                        },
                      ),
                      Gaps.h16,
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              key: ValueKey(_selectedGroup),
                              initialValue: _selectedGroup,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: loc.questionGroup,
                                border: const OutlineInputBorder(),
                              ),
                              items: _groups
                                  .map(
                                    (group) => DropdownMenuItem(
                                      value: group,
                                      child: Tooltip(
                                        message: group,
                                        child: Text(
                                          group,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() => _selectedGroup = value);
                                      _load();
                                    },
                            ),
                          ),
                          if (_selectedGroup != null) ...[
                            Gaps.w8,
                            IconButton(
                              tooltip: loc.clear,
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() => _selectedGroup = null);
                                      _load();
                                    },
                              icon: const Icon(Icons.filter_alt_off),
                            ),
                          ],
                        ],
                      ),
                      Gaps.h16,
                      DropdownButtonFormField<_QuestionStatusFilter>(
                        initialValue: _statusFilter,
                        decoration: InputDecoration(
                          labelText: loc.questionStatus,
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: _QuestionStatusFilter.all,
                            child: Text(loc.allQuestionStatuses),
                          ),
                          DropdownMenuItem(
                            value: _QuestionStatusFilter.active,
                            child: Text(loc.activeQuestion),
                          ),
                          DropdownMenuItem(
                            value: _QuestionStatusFilter.inactive,
                            child: Text(loc.inactiveQuestion),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _statusFilter = value);
                                  _load();
                                }
                              },
                      ),
                      Gaps.h16,
                      if (_questions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text(loc.noMyQuestions)),
                        ),
                      ..._questions.map((question) {
                        final isBusy = _deletingIds.contains(question.id) ||
                            _updatingIds.contains(question.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              title: Text(question.question),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${loc.correctAnswer}: ${question.answer}',
                                  ),
                                  Text(
                                    '${loc.questionGroup}: ${question.group}',
                                  ),
                                  Text('${loc.gameLevel}: ${question.level}'),
                                  Text(
                                    '${loc.questionStatus}: '
                                    '${question.isActive ? loc.activeQuestion : loc.inactiveQuestion}',
                                  ),
                                  if (question.options?.isNotEmpty == true)
                                    Text(
                                      '${loc.answerOptions}: ${question.options}',
                                    ),
                                ],
                              ),
                              trailing: isBusy
                                  ? const SizedBox.square(
                                      dimension: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: loc.edit,
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: _isLoading
                                              ? null
                                              : () => _edit(question),
                                        ),
                                        PopupMenuButton<String>(
                                          enabled: !_isLoading,
                                          onSelected: (action) {
                                            if (action == 'toggle') {
                                              _setActive(
                                                question,
                                                !question.isActive,
                                              );
                                            } else if (action == 'delete') {
                                              _delete(question);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(
                                                question.isActive
                                                    ? loc.deactivateQuestion
                                                    : loc.reactivateQuestion,
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Text(loc.delete),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        );
                      }),
                      if (_hasMore) ...[
                        Gaps.h8,
                        Center(
                          child: TextButton(
                            onPressed: _isLoadingMore
                                ? null
                                : () => _load(append: true),
                            child: _isLoadingMore
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(loc.clickHereToSeeMore),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
