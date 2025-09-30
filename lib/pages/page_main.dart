import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_calendar.dart';
import 'package:life_pilot/pages/specific/page_memory_trace.dart';
import 'package:life_pilot/pages/specific/page_recommended_attractions.dart';
import 'package:life_pilot/pages/specific/page_recommended_event.dart';
import 'package:life_pilot/pages/page_type.dart';
import 'package:life_pilot/utils/utils_const.dart';
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
  AppLocalizations get loc => AppLocalizations.of(context)!;
  late ControllerAuth _auth;

  late final Map<PageType, WidgetBuilder> _pageMap = {
    PageType.personalEvent: (_) => PageCalendar(),
    PageType.settings: (_) => const PageA(),
    PageType.recommendedEvent: (_) => PageRecommendedEvent(),
    PageType.recommendedAttractions: (_) => PageRecommendedAttractions(),
    PageType.memoryTrace: (_) => const PageMemoryTrace(),
    PageType.accountRecords: (_) => const PageA(),
    PageType.pointsRecord: (_) => const PageA(),
    PageType.game: (_) => const PageA(),
    PageType.ai: (_) => const PageA(),
  };

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = Provider.of<ControllerAuth>(context,listen:true);
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final defaultPage =
          _auth.isAnonymous ? PageType.recommendedEvent : PageType.personalEvent;
      setState(() {
        _selectedPage = defaultPage;
      });
      _updatePagesChanged(defaultPage, context: context);
    });

    final currentLocale = Localizations.localeOf(context);
    if (_lastLocale != currentLocale && _selectedPage != null) {
      _lastLocale = currentLocale;
      _updatePagesChanged(_selectedPage!, context: context);
    }
  }

  void _updatePagesChanged(PageType selected,{required BuildContext context}) {
    final pages = [
      _buildDropdown(selected, context: context),
      kGapW8(),
    ];

    widget.onPagesChanged?.call(pages);
  }

  Widget _buildDropdown(PageType selected, {required BuildContext context}) {
    
    final pageTitles = _getPageTitles(context: context); //loc, isAnonymous

    return DropdownButtonHideUnderline(
      child: DropdownButton<PageType>(
        value: selected,
        style: const TextStyle(
          color: Colors.white,
        ),
        dropdownColor: Color(0xFF0066CC),
        iconEnabledColor: Colors.white,
        items: pageTitles.map((pageType) {
          return DropdownMenuItem<PageType>(
            value: pageType,
            child: Text(pageType.title(loc)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null && value != _selectedPage) {
            _selectedPage = value;
            _updatePagesChanged(value, context: context);
            setState(() {});
          }
        },
      ),
    );
  }

  Widget _buildSelectedPage() {
    final builder = _pageMap[_selectedPage];
    return builder != null ? builder(context) : const SizedBox.shrink();
  }

  List<PageType> _getPageTitles({required BuildContext context}) {
    ControllerAuth auth = Provider.of<ControllerAuth>(context, listen: false);
    return auth.isAnonymous ? [PageType.recommendedEvent] : PageType.values;
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
