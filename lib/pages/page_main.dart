import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_calendar.dart';
import 'package:life_pilot/pages/specific/page_memory_trace.dart';
import 'package:life_pilot/pages/specific/page_recommended_attractions.dart';
import 'package:life_pilot/pages/specific/page_recommended_event.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  final void Function(List<Widget>)? onPagesChanged;
  const PageMain({super.key, this.onPagesChanged});

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  PageType? _selectedPage;
  Locale? _lastLocale;
  bool _initialized = false;
  late AppLocalizations _loc;
  late ControllerAuth _auth;

  late final Map<PageType, WidgetBuilder> _pageMap = {
    PageType.personalEvent: (_) => const PageCalendar(),
    PageType.settings: (_) => const PageA(),
    PageType.recommendedEvent: (_) => PageRecommendedEvent(),
    PageType.recommendedAttractions: (_) => PageRecommendedAttractions(),
    PageType.memoryTrace: (_) => const PageMemoryTrace(),
    PageType.accountRecords: (_) => const PageA(),
    PageType.pointsRecord: (_) => const PageA(),
    PageType.game: (_) => const PageA(),
    PageType.ai: (_) => const PageA(),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loc = AppLocalizations.of(context)!;
    _auth = Provider.of<ControllerAuth>(context, listen: false);
    // 初始化選擇頁面 (只初始化一次)
    if (!_initialized) {
      _initialized = true;
      final defaultPage = _auth.isAnonymous
          ? PageType.recommendedEvent
          : PageType.personalEvent;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedPage = defaultPage;
        });
        _updatePagesChanged(selected: defaultPage);
      });
    }

    // 監聽 locale 變化
    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale && _selectedPage != null) {
      _lastLocale = currentLocale;
      _updatePagesChanged(selected: _selectedPage!);
    }
  }

  void _updatePagesChanged({required PageType selected}) {
    final pages = [
      _buildDropdown(selected: selected),
      kGapW8(),
    ];

    widget.onPagesChanged?.call(pages);
  }

  Widget _buildDropdown({required PageType selected}) {
    final pageTitles = _auth.isAnonymous
        ? [PageType.recommendedEvent, PageType.recommendedAttractions]
        : PageType.values;
    return DropdownButtonHideUnderline(
      child: DropdownButton<PageType>(
        value: selected,
        style: const TextStyle(
          color: Colors.white,
        ),
        dropdownColor: const Color(0xFF0066CC),
        iconEnabledColor: Colors.white,
        items: pageTitles.map((pageType) {
          return DropdownMenuItem<PageType>(
            value: pageType,
            child: Text(pageType.title(_loc)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && value != _selectedPage) {
            setState(() {
              _selectedPage = value;
            });
            _updatePagesChanged(selected: value);
          }
        },
      ),
    );
  }

  Widget _buildSelectedPage() {
    final builder = _pageMap[_selectedPage];
    return builder != null ? builder(context) : const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox.expand(
        child: Padding(
      padding: kGapEIL1R1T8B1,
      child: _buildSelectedPage(),
    ));
  }
}
