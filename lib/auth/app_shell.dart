import 'package:flutter/material.dart';
import 'package:life_pilot/apps/page_main.dart';
import 'package:life_pilot/auth/page_auth_check.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MainPageBar(),
      body: const PageMain(),
    );
  }
}
