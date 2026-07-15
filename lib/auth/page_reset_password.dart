import 'package:flutter/material.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

class PageResetPassword extends StatefulWidget {
  final VoidCallback onBack;
  const PageResetPassword({super.key, required this.onBack});

  @override
  State<PageResetPassword> createState() => _PageResetPasswordState();
}

class _PageResetPasswordState extends State<PageResetPassword> {
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocusNode;
  late final ModelAuthView _authView; // ✅ 改用 Model 層來管理 ControllerAuth

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authView = context.read<ModelAuthView>(); // ✅ 使用 Model 來統一處理狀態
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword(AppLocalizations loc) async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      AppNavigator.showErrorBar(
          _authView.showLoginError(message: ErrorFields.noPasswordError, loc: loc));
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      AppNavigator.showErrorBar(
          _authView.showLoginError(message: ErrorFields.noRecoverySession, loc: loc));
      return;
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          password: password,
        ),
      );
      await Supabase.instance.client.auth.signOut();
      if (!mounted) {
        return;
      }
      widget.onBack();
    } catch (e) {
      logger.e('Reset Password Error: $e');
      AppNavigator.showErrorBar(
        _authView.showLoginError(message: ErrorFields.resetPasswordError, loc: loc));
      return;
    }
  }

  void _goBack() {
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 只監聽 ProviderLocale 的變化
    return Consumer<ProviderLocale>(builder: (context, localeProvider, _) {
      final loc = AppLocalizations.of(context)!;
      return SingleChildScrollView(
        padding: Insets.all12,
        child: Column(
          children: [
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              decoration: InputDecoration(labelText: loc.password),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                await _updatePassword(loc);
              },
            ),
            Gaps.h16,
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _updatePassword(loc);
                  },
                  child: Text(loc.updatePassword),
                ),
                Gaps.w8,
                TextButton(
                  onPressed: _goBack,
                  child: Text(loc.back),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
