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
  bool _isLoading = true;
  bool _hasError = false;
  final Set<String> _deletingIds = {};
  final Set<String> _updatingIds = {};
  final TextEditingController _searchController = TextEditingController();
  String? _selectedGroup;
  _QuestionStatusFilter _statusFilter = _QuestionStatusFilter.all;

  List<String> get _groups {
    final groups = _questions
        .map((question) => question.group)
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return groups;
  }

  List<MyGameQuestion> get _filteredQuestions {
    final keyword = _searchController.text.trim().toLowerCase();
    return _questions.where((question) {
      if (_selectedGroup != null && question.group != _selectedGroup) {
        return false;
      }
      if (_statusFilter == _QuestionStatusFilter.active && !question.isActive) {
        return false;
      }
      if (_statusFilter == _QuestionStatusFilter.inactive &&
          question.isActive) {
        return false;
      }
      if (keyword.isEmpty) return true;
      return question.question.toLowerCase().contains(keyword) ||
          question.answer.toLowerCase().contains(keyword) ||
          question.group.toLowerCase().contains(keyword);
    }).toList();
  }

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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final questions =
          await _service.fetchMyQuestions(gameName: widget.gameName);
      if (!mounted) return;
      setState(() => _questions = questions);
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      setState(() {
        _questions =
            _questions.where((existing) => existing.id != question.id).toList();
      });
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
      setState(() {
        _questions = _questions
            .map(
              (existing) => existing.id == question.id
                  ? MyGameQuestion(
                      id: existing.id,
                      question: existing.question,
                      answer: existing.answer,
                      group: existing.group,
                      level: existing.level,
                      isActive: isActive,
                      options: existing.options,
                    )
                  : existing,
            )
            .toList();
      });
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
    final filteredQuestions = _filteredQuestions;
    return Scaffold(
      appBar: AppBar(title: Text(loc.myQuestions)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
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
              : _questions.isEmpty
                  ? Center(child: Text(loc.noMyQuestions))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: loc.search,
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.clear),
                                    ),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          Gaps.h16,
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey(_selectedGroup),
                                  initialValue: _selectedGroup,
                                  decoration: InputDecoration(
                                    labelText: loc.questionGroup,
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: _groups
                                      .map(
                                        (group) => DropdownMenuItem(
                                          value: group,
                                          child: Text(
                                            group,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => _selectedGroup = value),
                                ),
                              ),
                              if (_selectedGroup != null) ...[
                                Gaps.w8,
                                IconButton(
                                  tooltip: loc.clear,
                                  onPressed: () =>
                                      setState(() => _selectedGroup = null),
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
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _statusFilter = value);
                              }
                            },
                          ),
                          Gaps.h16,
                          if (filteredQuestions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(child: Text(loc.noMyQuestions)),
                            ),
                          ...filteredQuestions.map((question) {
                            final isBusy = _deletingIds.contains(question.id) ||
                                _updatingIds.contains(question.id);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Card(
                                child: ListTile(
                                  title: Text(question.question),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${loc.correctAnswer}: ${question.answer}',
                                      ),
                                      Text(
                                        '${loc.questionGroup}: ${question.group}',
                                      ),
                                      Text(
                                          '${loc.gameLevel}: ${question.level}'),
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
                                              icon: const Icon(
                                                  Icons.edit_outlined),
                                              onPressed: () => _edit(question),
                                            ),
                                            PopupMenuButton<String>(
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
                                                        : loc
                                                            .reactivateQuestion,
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
                        ],
                      ),
                    ),
    );
  }
}
