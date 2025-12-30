import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PageAI extends StatelessWidget {
  const PageAI({super.key});

  Future<void> _openChatGPT() async {
    final uri = Uri.parse('https://chatgpt.com/zh-TW');

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // ⭐ 一定要 external
    )) {
      throw Exception('Could not launch ChatGPT');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.smart_toy),
        label: const Text('Open ChatGPT'),
        onPressed: _openChatGPT,
      ),
    );
  }
}
