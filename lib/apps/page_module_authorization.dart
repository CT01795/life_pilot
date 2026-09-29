import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/apps/service_module.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PageModuleAuthorization extends StatefulWidget {
  const PageModuleAuthorization({super.key});

  @override
  State<PageModuleAuthorization> createState() =>
      _PageModuleAuthorizationState();
}

class _PageModuleAuthorizationState extends State<PageModuleAuthorization> {
  final _emailController = TextEditingController();
  final _service = ServiceModule();
  final _selectedKeys = <String>{};
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final loc = AppLocalizations.of(context)!;
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _message(loc.moduleAuthorizationSearchFirst);
      return;
    }
    setState(() => _loading = true);
    try {
      final keys = await _service.loadUserModulesAsAdmin(email);
      if (!mounted) return;
      setState(() {
        _selectedKeys
          ..clear()
          ..addAll(keys);
        _searched = true;
      });
    } catch (error, stackTrace) {
      logger.e(
        'Failed to load module authorization',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _message(_errorMessage(loc, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final loc = AppLocalizations.of(context)!;
    if (!_searched) {
      _message(loc.moduleAuthorizationSearchFirst);
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.saveUserModulesAsAdmin(
        account: _emailController.text,
        moduleKeys: _selectedKeys,
      );
      final savedKeys = await _service.loadUserModulesAsAdmin(
        _emailController.text,
      );
      if (!mounted) return;
      final savedSet = savedKeys.toSet();
      if (savedSet.length != _selectedKeys.length ||
          !savedSet.containsAll(_selectedKeys)) {
        _message(loc.moduleAuthorizationSaveFailed);
        return;
      }
      setState(() {
        _selectedKeys
          ..clear()
          ..addAll(savedSet);
      });
      _message(loc.moduleAuthorizationSaved);
    } catch (error, stackTrace) {
      logger.e(
        'Failed to save module authorization',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _message(_errorMessage(loc, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _errorMessage(AppLocalizations loc, Object error) {
    if (error case PostgrestException(
      :final code,
    ) when code == 'PGRST202' || code == '42883') {
      return loc.moduleAuthorizationNotDeployed;
    }
    if (error case PostgrestException(:final code) when code == 'P0002') {
      return loc.moduleAuthorizationUserNotFound;
    }
    return loc.moduleAuthorizationLoadFailed;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final auth = context.watch<ControllerAuth>();
    if (!auth.isSysAdmin) {
      return const Scaffold(body: Center(child: Icon(Icons.lock_outline)));
    }
    return Scaffold(
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
                      Text(
                        loc.moduleAuthorization,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Gaps.h8,
                      Text(loc.moduleAuthorizationDescription),
                      Gaps.h16,
                      TextField(
                        controller: _emailController,
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
                            value: _selectedKeys.contains(entry.value),
                            title: Text(entry.key.title(loc: loc)),
                            secondary: Icon(_iconFor(entry.key)),
                            onChanged: (selected) => setState(() {
                              if (selected ?? false) {
                                _selectedKeys.add(entry.value);
                              } else {
                                _selectedKeys.remove(entry.value);
                              }
                            }),
                          ),
                        if (_selectedKeys.isEmpty)
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
    PageType.game => Icons.sports_esports_outlined,
    PageType.ai => Icons.smart_toy_outlined,
    PageType.stock => Icons.candlestick_chart_outlined,
    PageType.businessPlan => Icons.business_center_outlined,
    PageType.feedbackAdmin => Icons.feedback_outlined,
    _ => Icons.extension_outlined,
  };
}
