import 'package:flutter/material.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/core/provider_locale.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/auth/model_auth_view.dart';
import 'package:provider/provider.dart';

class PageRegister extends StatefulWidget {
  final String? email;
  final String? password;
  final void Function(String email, String password) onBack;
  const PageRegister(
      {super.key, this.email, this.password, required this.onBack});

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;
  late final ModelAuthView _authView; // ✅ 改用 Model 層來管理 ControllerAuth

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? constEmpty);
    _passwordController =
        TextEditingController(text: widget.password ?? constEmpty);
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authView = context.read<ModelAuthView>(); // ✅ 使用 Model 來統一處理狀態
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tryRegister(AppLocalizations loc) async {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final error = await _authView.register(email: email, password: password);

    if (!mounted) return;

    if (error?.isNotEmpty ?? false) {
      AppNavigator.showErrorBar(
          _authView.showLoginError(message: error!, loc: loc));
    }
  }

  void _goBack() {
    widget.onBack(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
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
              controller: _emailController,
              focusNode: _emailFocusNode,
              textCapitalization: TextCapitalization.none, //避免 email 被自動大寫
              keyboardType: TextInputType.emailAddress, //email 鍵盤類型
              obscureText: false,
              decoration: InputDecoration(labelText: loc.email),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) {
                _passwordFocusNode.requestFocus(); // 跳到下一個輸入欄
              },
            ),
            Gaps.h16,
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              obscureText: true,
              decoration: InputDecoration(labelText: loc.password),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) async {
                await _tryRegister(loc);
              },
            ),
            Gaps.h16,
            Row(
              children: [
                ElevatedButton(
                  child: Text(loc.register),
                  onPressed: () async {
                    await _tryRegister(loc);
                  },
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
