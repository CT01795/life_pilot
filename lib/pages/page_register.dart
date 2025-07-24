import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_recommended_event.dart';
import 'package:life_pilot/services/service_auth.dart';
import 'package:life_pilot/utils/handler_message.dart';
import 'package:life_pilot/utils/ui_input_field.dart';

class PageRegister extends StatefulWidget {
  final String? email; // 新增 email 欄位來儲存傳入的 email
  final String? password; // 新增 password 欄位來儲存傳入的 password
  const PageRegister({super.key, this.email, this.password});

  @override
  State<PageRegister> createState() => _PageRegisterState();
}

class _PageRegisterState extends State<PageRegister> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email!;  // 在此處設置初始值
    _passwordController.text = widget.password!;  // 在此處設置初始值
  }

  void _register() async {
    final loc = AppLocalizations.of(context)!;
    final result = await AuthService.register(
      _emailController.text,
      _passwordController.text,
    );

    if (result == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => PageRecommendedEvent()));
    } else {
      showLoginError(context, result, loc);  // 使用共用的錯誤處理函數
    }
  }

  // 當用戶按返回時，傳遞 email 返回上一頁
  void _onBackPressed() {
    Navigator.pop(context, {
      'email': _emailController.text, 
      'password': _passwordController.text
    });  // 傳遞 email 回上一頁
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.register),
        // 在返回按鈕上設定行為
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _onBackPressed, // 按下返回時執行的回調
        ),),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            InputField(controller: _emailController, labelText: loc.email),
            InputField(controller: _passwordController, labelText: loc.password, obscureText: true),
            const SizedBox(height: 16),
            ActionButton(label: loc.register, onPressed: _register),  // 使用共用的按鈕組件
          ],
        ),
      ),
    );
  }
}
