import 'package:flutter/material.dart';
import 'package:life_pilot/game/controller_game_my_questions.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/page_game_question_create.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:provider/provider.dart';

typedef GameQuestionCreatePageBuilder =
    Widget Function(
      String initialQuestion,
      String? initialGroup,
      int initialLevel,
    );

class PageGameMyQuestions extends StatefulWidget {
  const PageGameMyQuestions({
    super.key,
    required this.gameName,
    required this.initialLevel,
    this.service,
    this.createPageBuilder,
  });

  final String gameName;
  final int initialLevel;
  final ServiceGame? service;
  final GameQuestionCreatePageBuilder? createPageBuilder;

  @override
  State<PageGameMyQuestions> createState() => _PageGameMyQuestionsState();
}

class _PageGameMyQuestionsState extends State<PageGameMyQuestions> {
  late final ControllerGameMyQuestions _controller;
  final TextEditingController _searchController = TextEditingController();

  List<MyGameQuestion> get _questions => _controller.questions;
  List<String> get _groups => _controller.groups;
  bool get _isLoading => _controller.isLoading;
  bool get _isLoadingMore => _controller.isLoadingMore;
  bool get _hasLoaded => _controller.hasLoaded;
  bool get _hasError => _controller.hasError;
  bool get _hasMore => _controller.hasMore;
  String get _appliedKeyword => _controller.appliedKeyword;
  String? get _selectedGroup => _controller.selectedGroup;
  QuestionStatusFilter get _statusFilter => _controller.statusFilter;

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = ControllerGameMyQuestions(
      service: widget.service ?? ServiceGame(),
      gameName: widget.gameName,
    )..addListener(_onControllerChanged);
    _load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false, bool refreshGroups = true}) async {
    final succeeded = await _controller.load(
      append: append,
      refreshGroups: refreshGroups,
    );
    if (succeeded == false && mounted && (append || _hasLoaded)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
      );
    }
  }

  Future<void> _delete(MyGameQuestion question) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed =
        await showDialog<bool>(
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

    try {
      await _controller.deleteQuestion(question.id);
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await context.read<ControllerAuth>().refreshSubscriptionUsage();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.questionDeleted)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
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

  Future<void> _add() async {
    final createPage =
        widget.createPageBuilder?.call(
          _appliedKeyword,
          _selectedGroup,
          widget.initialLevel,
        ) ??
        PageGameQuestionCreate(
          gameName: widget.gameName,
          initialLevel: widget.initialLevel,
          initialQuestion: _appliedKeyword,
          initialGroup: _selectedGroup,
        );
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => createPage),
    );
    if (added == true && mounted) await _load();
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();
    _controller.applySearch(_searchController.text);
    _load(refreshGroups: false);
  }

  Future<void> _setActive(MyGameQuestion question, bool isActive) async {
    final loc = AppLocalizations.of(context)!;
    try {
      await _controller.setQuestionActive(question.id, isActive);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.questionStatusUpdateFailed)));
      }
    }
  }

  Widget _buildFilters(AppLocalizations loc) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SubscriptionUsageBanner(resource: 'game_questions'),
      if (_isLoading) ...[const LinearProgressIndicator(), Gaps.h16],
      TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: loc.search,
          helperText: loc.questionSearchGuidance,
          helperMaxLines: 2,
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.text.isNotEmpty)
                  IconButton(
                    tooltip: loc.clear,
                    onPressed: _isLoading
                        ? null
                        : () {
                            _searchController.clear();
                            _controller.applySearch('');
                            _load(refreshGroups: false);
                          },
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: loc.search,
                  onPressed: _isLoading ? null : _applySearch,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          border: const OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          if (!_isLoading) _applySearch();
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
                      _controller.selectGroup(value);
                      _load(refreshGroups: false);
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
                      _controller.selectGroup(null);
                      _load(refreshGroups: false);
                    },
              icon: const Icon(Icons.filter_alt_off),
            ),
          ],
        ],
      ),
      Gaps.h16,
      DropdownButtonFormField<QuestionStatusFilter>(
        initialValue: _statusFilter,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: loc.questionStatus,
          border: const OutlineInputBorder(),
        ),
        items: [
          DropdownMenuItem(
            value: QuestionStatusFilter.all,
            child: Text(loc.allQuestionStatuses),
          ),
          DropdownMenuItem(
            value: QuestionStatusFilter.active,
            child: Text(loc.activeQuestion),
          ),
          DropdownMenuItem(
            value: QuestionStatusFilter.inactive,
            child: Text(loc.inactiveQuestion),
          ),
        ],
        onChanged: _isLoading
            ? null
            : (value) {
                if (value != null) {
                  _controller.selectStatus(value);
                  _load(refreshGroups: false);
                }
              },
      ),
      Gaps.h16,
      if (_questions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(loc.noMyQuestions),
              if (_appliedKeyword.isNotEmpty) ...[
                Gaps.h16,
                FilledButton.icon(
                  onPressed: _isLoading ? null : _add,
                  icon: const Icon(Icons.add),
                  label: Text(loc.addQuestion),
                ),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _buildQuestionCard(MyGameQuestion question, AppLocalizations loc) {
    final isBusy = _controller.isBusy(question.id);
    return Padding(
      key: ValueKey(question.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: RepaintBoundary(
        key: ValueKey(question.id),
        child: Card(
          child: ListTile(
            title: Text(
              question.question,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${loc.correctAnswer}: ${question.answer}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${loc.questionGroup}: ${question.group}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${loc.gameLevel}: ${question.level}'),
                Text(
                  '${loc.questionStatus}: '
                  '${question.isActive ? loc.activeQuestion : loc.inactiveQuestion}',
                ),
                if (question.options?.isNotEmpty == true)
                  Text(
                    '${loc.answerOptions}: ${question.options}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            trailing: isBusy
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PopupMenuButton<String>(
                    enabled: !_isLoading,
                    onSelected: (action) {
                      if (action == 'edit') {
                        _edit(question);
                      } else if (action == 'toggle') {
                        _setActive(question, !question.isActive);
                      } else if (action == 'delete') {
                        _delete(question);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(loc.edit)),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          question.isActive
                              ? loc.deactivateQuestion
                              : loc.reactivateQuestion,
                        ),
                      ),
                      PopupMenuItem(value: 'delete', child: Text(loc.delete)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore(AppLocalizations loc) => Column(
    children: [
      Gaps.h8,
      Center(
        child: TextButton(
          onPressed: _isLoadingMore ? null : () => _load(append: true),
          child: _isLoadingMore
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.clickHereToSeeMore),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final questions = _questions;
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
                  ElevatedButton(onPressed: _load, child: Text(loc.retry)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: questions.length + 1 + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) return _buildFilters(loc);
                  if (index > questions.length) return _buildLoadMore(loc);
                  return _buildQuestionCard(questions[index - 1], loc);
                },
              ),
            ),
    );
  }
}
