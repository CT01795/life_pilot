import 'package:flutter/material.dart';
import 'package:life_pilot/game/social/controller_game_social_questions.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/social/page_game_social_question_create.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:provider/provider.dart';

typedef SocialQuestionCreatePageBuilder =
    Widget Function(String initialTitle, String? initialCategory);

class PageGameSocialQuestions extends StatefulWidget {
  const PageGameSocialQuestions({
    super.key,
    this.service,
    this.createPageBuilder,
  });

  final ServiceGame? service;
  final SocialQuestionCreatePageBuilder? createPageBuilder;

  @override
  State<PageGameSocialQuestions> createState() => _PageState();
}

class _PageState extends State<PageGameSocialQuestions> {
  late final ControllerGameSocialQuestions _controller;
  final _searchController = TextEditingController();
  String get _appliedKeyword => _controller.appliedKeyword;
  List<MySocialQuestion> get _questions => _controller.questions;
  List<String> get _categories => _controller.categories;
  int get _totalCount => _controller.totalCount;
  bool get _loading => _controller.isLoading;
  bool get _loadingMore => _controller.isLoadingMore;
  bool get _loaded => _controller.hasLoaded;
  bool get _loadError => _controller.hasError;
  String? get _selectedCategory => _controller.selectedCategory;
  SocialQuestionStatusFilter get _status => _controller.status;
  bool get _hasMore => _controller.hasMore;

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _controller = ControllerGameSocialQuestions(
      service: widget.service ?? ServiceGame(),
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

  Future<void> _load({
    bool append = false,
    bool refreshCategories = false,
  }) async {
    final result = await _controller.load(
      append: append,
      refreshCategories: refreshCategories,
    );
    if (result == false && mounted && (append || _loaded)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
      );
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
    if (mounted && changed == true) {
      _controller.invalidateCategories();
      await _load();
    }
  }

  Future<void> _add() async {
    final createPage =
        widget.createPageBuilder?.call(_appliedKeyword, _selectedCategory) ??
        PageGameSocialQuestionCreate(
          initialTitle: _appliedKeyword,
          initialCategory: _selectedCategory,
        );
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => createPage),
    );
    if (added == true && mounted) {
      _controller.invalidateCategories();
      await _load();
    }
  }

  void _applySearch() {
    FocusScope.of(context).unfocus();
    _controller.applySearch(_searchController.text);
    _load();
  }

  Future<void> _toggle(MySocialQuestion question) async {
    final loc = AppLocalizations.of(context)!;
    final nextValue = !question.isActive;
    try {
      if (!await _controller.setQuestionActive(question.id, nextValue)) return;
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? loc.questionReactivated : loc.questionDeactivated,
          ),
        ),
      );
    } catch (error, stackTrace) {
      logger.e(
        'Update Social status failed',
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

  Future<void> _delete(MySocialQuestion question) async {
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
      if (!await _controller.deleteQuestion(question.id)) return;
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
        'Delete Social question failed',
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.myQuestions)),
      body: _loading && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _loadError && !_loaded
          ? Center(
              child: ElevatedButton(onPressed: _load, child: Text(loc.retry)),
            )
          : RefreshIndicator(
              onRefresh: () => _load(refreshCategories: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.list(
                      children: [
                        const SubscriptionUsageBanner(
                          resource: 'game_questions',
                        ),
                        if (_loading) ...[
                          const LinearProgressIndicator(),
                          Gaps.h16,
                        ],
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: loc.searchKeywords,
                            helperText: loc.questionSearchGuidance,
                            helperMaxLines: 2,
                            border: const OutlineInputBorder(),
                            suffixIcon:
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _searchController,
                                  builder: (context, value, _) => Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (value.text.isNotEmpty)
                                        IconButton(
                                          tooltip: loc.clear,
                                          onPressed: _loading
                                              ? null
                                              : () {
                                                  _searchController.clear();
                                                  _controller.applySearch('');
                                                  _load();
                                                },
                                          icon: const Icon(Icons.clear),
                                        ),
                                      IconButton(
                                        tooltip: loc.search,
                                        onPressed: _loading
                                            ? null
                                            : _applySearch,
                                        icon: const Icon(Icons.search),
                                      ),
                                    ],
                                  ),
                                ),
                          ),
                          textInputAction: TextInputAction.search,
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
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Text(
                                          category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loading
                                    ? null
                                    : (value) {
                                        _controller.selectCategory(value);
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
                                        _controller.selectCategory(null);
                                        _load();
                                      },
                                icon: const Icon(Icons.filter_alt_off),
                              ),
                            ],
                          ],
                        ),
                        Gaps.h16,
                        DropdownButtonFormField<SocialQuestionStatusFilter>(
                          initialValue: _status,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: loc.questionStatus,
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: SocialQuestionStatusFilter.all,
                              child: Text(loc.allQuestionStatuses),
                            ),
                            DropdownMenuItem(
                              value: SocialQuestionStatusFilter.active,
                              child: Text(loc.activeQuestion),
                            ),
                            DropdownMenuItem(
                              value: SocialQuestionStatusFilter.inactive,
                              child: Text(loc.inactiveQuestion),
                            ),
                          ],
                          onChanged: _loading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    _controller.selectStatus(value);
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
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: _questions.length,
                      addAutomaticKeepAlives: false,
                      itemBuilder: (_, index) => _card(_questions[index], loc),
                    ),
                  ),
                  if (_hasMore)
                    SliverToBoxAdapter(
                      child: Center(
                        child: TextButton(
                          onPressed: _loadingMore
                              ? null
                              : () => _load(append: true),
                          child: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(loc.clickHereToSeeMore),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _card(MySocialQuestion question, AppLocalizations loc) {
    final busy = _controller.isBusy(question.id);
    return RepaintBoundary(
      key: ValueKey(question.id),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(
            question.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
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
              : PopupMenuButton<String>(
                  enabled: !_loading,
                  onSelected: (action) {
                    if (action == 'edit') {
                      _edit(question);
                    } else if (action == 'toggle') {
                      _toggle(question);
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
    );
  }
}
