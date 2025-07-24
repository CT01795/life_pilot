import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_login.dart';
import 'package:life_pilot/services/service_auth.dart';

class PageRecommendedEvent extends StatefulWidget {
  const PageRecommendedEvent({super.key});

  @override
  State<PageRecommendedEvent> createState() => _PageRecommendedEventState();
}

class _PageRecommendedEventState extends State<PageRecommendedEvent> {
  void _logout() async {
    final loc = AppLocalizations.of(context)!;
    var email = await AuthService.currentAccount();
    final result = await AuthService.logout();

    if (result == null) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => PageLogin(email: email)));
    } else {
      // 顯示錯誤訊息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.logoutError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.logout)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextButton(
              onPressed: _logout,
              child: Text(loc.logout),
            ),
          ],
        ),
      ),
    );
  }
}
