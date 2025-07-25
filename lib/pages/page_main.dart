import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/utils/gaps.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  final void Function(List<Widget>)? onPagesChanged; // 👈 宣告這個 callback
  const PageMain({super.key, this.onPagesChanged}); // 👈 加上這個
  
  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  String? _selectedPage;

  @override
  void initState() {
    super.initState();
    // 延後初始化，避免直接使用 context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);      
      final selected = auth.isAnonymous ? 'recommended_event' : 'personal_event';
      setState(() {
        _selectedPage = selected;
      });
       _updatePagesChanged(selected);
    });
  }

  // 產生 DropdownButton 並通知外層
  void _updatePagesChanged(String selected) {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    final pages = [
      _buildDropdown(loc, auth.isAnonymous, selected),
      kGapW16,
    ];

    widget.onPagesChanged?.call(pages);
  }

  // 建立 DropdownButton Widget
  Widget _buildDropdown(AppLocalizations loc, bool isAnonymous, String selected) {
    final pageTitles = _getPageTitles(loc, isAnonymous);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        items: pageTitles.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && value != _selectedPage) {
            setState(() {
              _selectedPage = value;
            });
            _updatePagesChanged(value);
          }
        },
      ),
    );
  }
  
  Widget _buildSelectedPage() {
    switch (_selectedPage) {
      case 'recommended_event':
        return const PageA();
      case 'personal_event':
        return const PageA();
      default:
        return const SizedBox.shrink();
    }
  }

  Map<String, String> _getPageTitles(AppLocalizations loc, bool isAnonymous) {
    return isAnonymous
      ? {
          'recommended_event': loc.recommended_event,
        }
      : {
          'recommended_event': loc.recommended_event,
          'personal_event': loc.personal_event,
        };
  }

  @override
  Widget build(BuildContext context) {
    // 避免頁面初始化前顯示錯誤內容
    if (_selectedPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox.expand( // 限制高度
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildSelectedPage(),
      )
    );
  }
}