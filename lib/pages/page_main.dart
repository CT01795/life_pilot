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
  Locale? _lastLocale;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale && _selectedPage != null) {
      _lastLocale = currentLocale;
      _updatePagesChanged(_selectedPage!);
    }
  }

  // 產生 DropdownButton 並通知外層
  void _updatePagesChanged(String selected) {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    final loc = AppLocalizations.of(context)!;

    final pages = [
      _buildDropdown(loc, auth.isAnonymous, selected),
      kGapW8,
    ];

    widget.onPagesChanged?.call(pages);
  }

  // 建立 DropdownButton Widget
  Widget _buildDropdown(AppLocalizations loc, bool isAnonymous, String selected) {
    final pageTitles = _getPageTitles(loc, isAnonymous);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        style: const TextStyle( // ✅ 修改這裡
          color: Colors.white, // 選單文字色
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Color(0xFF0066CC), // ✅ 背景色
        iconEnabledColor: Colors.white, // ✅ 下拉箭頭顏色
        items: pageTitles.entries.map((entry) {
          return DropdownMenuItem<String>(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && value != _selectedPage) {
            _selectedPage = value;
            _updatePagesChanged(value);
            setState(() {});
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