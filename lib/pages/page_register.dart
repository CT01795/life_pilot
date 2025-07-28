import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/gaps.dart';
import 'package:life_pilot/utils/handler_message.dart';
import 'package:life_pilot/utils/ui_input_field.dart';
import 'package:provider/provider.dart';

class PageRegister extends StatefulWidget {
  final String? email; // 新增 email 欄位來儲存傳入的 email
  final String? password; // 新增 password 欄位來儲存傳入的 password
  final void Function(String email, String password) onBack;
  const PageRegister({super.key, this.email, this.password, required this.onBack});

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email ?? '';
    _passwordController.text = widget.password ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _register() async {
    final loc = AppLocalizations.of(context)!;
    final result = await ServiceAuth.register(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      await auth.checkLoginStatus();
      // 註冊成功後外層會刷新畫面切換
    } else {
      showLoginError(context, result, loc); // 使用共用的錯誤處理函數
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Material(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: loc.email),
            kGapH16,
            InputField(
                controller: _passwordController,
                labelText: loc.password,
                obscureText: true),
            kGapH16,
            Row(
              children: [
                ActionButton(
                label: loc.register, onPressed: _register), // 使用共用的按鈕組件
                kGapW8,
                TextButton(
                  onPressed: () {
                    widget.onBack(
                      _emailController.text,
                      _passwordController.text,
                    );
                  },
                  child: Text(loc.back),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
