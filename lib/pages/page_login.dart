import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_recommended_event.dart';
import 'package:life_pilot/pages/page_register.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/handler_message.dart';
import 'package:life_pilot/utils/ui_input_field.dart';

class PageLogin extends StatefulWidget {
  final String? email; // 新增 email 欄位來儲存傳入的 email
  const PageLogin({super.key, this.email});

  @override
  State<PageLogin> createState() => _PageLoginState();
}

class _PageLoginState extends State<PageLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 初始化 _emailController，將傳入的 email 設置為控制器的文本
    _emailController.text = widget.email!; // 在此處設置初始值
  }

  void _login() async {
    final loc = AppLocalizations.of(context)!;
    final result = await AuthService.login(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => PageRecommendedEvent()));
    } else {
      showLoginError(context, result, loc); // 使用共用的錯誤處理函數
    }
  }

  // 重設密碼功能
  void _resetPassword() async {
    final loc = AppLocalizations.of(context)!;
    final result = await AuthService.resetPassword(_emailController.text);

    if (result == null) {
      /*Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PageLogin(email: _emailController.text)));*/
      showMessage(context, loc.resetPasswordEmail);
    } else {
      showLoginError(context, result, loc); // 使用共用的錯誤處理函數
    }
  }

  // 當返回 PageLogin 時，接收從 PageRegister 傳回的 email
  void _navigateToRegisterPage() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => PageRegister(
                  email: _emailController.text,
                  password: _passwordController.text,
                )));

    if (result != null) {
      // 設置 _emailController 和 _passwordController 的文本為返回的值
      _emailController.text = result['email']; // 接收 email
      _passwordController.text = result['password']; // 接收 password
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      //appBar: AppBar(title: Text(loc.login)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: loc.email),
            InputField(
                controller: _passwordController,
                labelText: loc.password,
                obscureText: true),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              ActionButton(label: loc.login, onPressed: _login), // 使用共用的按鈕組件
              SizedBox(
                width: 16,
              ),
              ActionButton(
                  label: loc.resetPassword,
                  onPressed: _resetPassword), // 使用共用的按鈕組件
              SizedBox(
                width: 16,
              ),
              TextButton(
                onPressed: _navigateToRegisterPage,
                child: Text(loc.register),
              ),
            ])
          ],
        ),
      ),
    );
  }
}
