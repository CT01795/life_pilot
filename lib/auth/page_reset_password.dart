import 'package:flutter/material.dart';
import 'package:life_pilot/utils/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

class PageResetPassword extends StatefulWidget {
  final VoidCallback onBack;
  const PageResetPassword(
      {super.key, required this.onBack});

  @override
  State<PageResetPassword> createState() => _PageResetPasswordState();
}

class _PageResetPasswordState extends State<PageResetPassword> {
  late final TextEditingController _passwordController;
  late final FocusNode _passwordFocusNode;

  @override
  void initState() {
    super.initState();
    _passwordController =
        TextEditingController();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _passwordFocusNode.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password =
        _passwordController.text.trim();
    if(password.isEmpty){
      return;
    }

    final user =
      Supabase.instance.client.auth.currentUser;
    if(user == null){
      logger.e(
        "No recovery session"
      );
      return;
    }

    try {
      await Supabase.instance.client.auth
          .updateUser(
            UserAttributes(
              password: password,
            ),
          );

      if(!mounted){
        return;
      }
      widget.onBack();
    } catch(e){
      logger.e(
        "Update password error: $e"
      );
    }
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
                await _updatePassword();
              },
            ),
            Gaps.h16,
            Row(
              children: [
                ElevatedButton(
                  onPressed: _updatePassword,
                  child: Text(loc.updatePassword),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
