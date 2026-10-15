import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/apps/controller_module_authorization.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class PageModuleAuthorization extends StatefulWidget {
  const PageModuleAuthorization({super.key, this.service});

  final ServiceModule? service;

  @override
  State<PageModuleAuthorization> createState() =>
      _PageModuleAuthorizationState();
}

class _PageModuleAuthorizationState extends State<PageModuleAuthorization> {
  final _emailController = TextEditingController();
  late final ControllerModuleAuthorization _controller;
  bool get _loading => _controller.isLoading;
  bool get _searched => _controller.hasSearched;

  @override
  void initState() {
    super.initState();
    _controller = ControllerModuleAuthorization(
      service: widget.service ?? ServiceModule(),
    )..addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final result = await _controller.search(_emailController.text);
    if (mounted) _showResult(result);
  }

  Future<void> _save() async {
    final result = await _controller.save();
    if (mounted) _showResult(result);
  }

  void _showResult(ModuleAuthorizationResult? result) {
    final loc = AppLocalizations.of(context)!;
    final message = switch (result) {
      null || ModuleAuthorizationResult.loaded => null,
      ModuleAuthorizationResult.saved => loc.moduleAuthorizationSaved,
      ModuleAuthorizationResult.searchFirst =>
        loc.moduleAuthorizationSearchFirst,
      ModuleAuthorizationResult.userNotFound =>
        loc.moduleAuthorizationUserNotFound,
      ModuleAuthorizationResult.notDeployed =>
        loc.moduleAuthorizationNotDeployed,
      ModuleAuthorizationResult.loadFailed => loc.moduleAuthorizationLoadFailed,
      ModuleAuthorizationResult.saveFailed => loc.moduleAuthorizationSaveFailed,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ControllerAuth>();
    final selectedKeys = _controller.selectedKeys;
    if (!auth.isSysAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.moduleAuthorization)),
        body: const Center(child: Icon(Icons.lock_outline)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(loc.moduleAuthorization)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(loc.moduleAuthorizationDescription),
                      Gaps.h16,
                      TextField(
                        controller: _emailController,
                        enabled: !_loading,
                        onChanged: _controller.setEmail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          labelText: loc.email,
                          prefixIcon: const Icon(Icons.person_search_outlined),
                          suffixIcon: IconButton(
                            onPressed: _loading ? null : _search,
                            icon: const Icon(Icons.search),
                            tooltip: loc.search,
                          ),
                        ),
                        onSubmitted: (_) => _loading ? null : _search(),
                      ),
                      Gaps.h16,
                      if (_loading)
                        const LinearProgressIndicator()
                      else if (!_searched)
                        Text(loc.moduleAuthorizationSearchFirst)
                      else ...[
                        for (final entry
                            in ControllerPageMain.grantablePageKeys.entries)
                          CheckboxListTile(
                            value: selectedKeys.contains(entry.value),
                            title: Text(entry.key.title(loc: loc)),
                            secondary: Icon(_iconFor(entry.key)),
                            onChanged: (selected) => _controller.setSelected(
                              entry.value,
                              selected ?? false,
                            ),
                          ),
                        if (selectedKeys.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(loc.moduleAuthorizationNoAccess),
                          ),
                        FilledButton.icon(
                          onPressed: _loading ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(loc.save),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(PageType page) => switch (page) {
    PageType.pointsRecord => Icons.stars_outlined,
    PageType.vendorDashboard => Icons.storefront_outlined,
    PageType.game => Icons.sports_esports_outlined,
    PageType.ai => Icons.smart_toy_outlined,
    PageType.stock => Icons.candlestick_chart_outlined,
    PageType.businessPlan => Icons.business_center_outlined,
    PageType.feedbackAdmin => Icons.feedback_outlined,
    _ => Icons.extension_outlined,
  };
}
