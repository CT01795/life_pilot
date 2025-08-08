import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/page_a.dart';
import 'package:life_pilot/pages/page_recommended_event.dart';
import 'package:life_pilot/utils/utils_gaps.dart';
import 'package:provider/provider.dart';

class PageMain extends StatefulWidget {
  final void Function(List<Widget>)? onPagesChanged; 
  const PageMain({super.key, this.onPagesChanged}); 

  @override
  State<PageMain> createState() => _PageMainState();
}

class _PageMainState extends State<PageMain> {
  String? _selectedPage;
  Locale? _lastLocale;
  AppLocalizations get loc => AppLocalizations.of(context)!; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<ControllerAuth>(context, listen: false);
      final selected =
          auth.isAnonymous ? 'recommended_event' : 'recommended_event';
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

  void _updatePagesChanged(String selected) {
    final auth = Provider.of<ControllerAuth>(context, listen: false);
    
    final pages = [
      _buildDropdown(loc, auth.isAnonymous, selected),
      kGapW8,
    ];

    widget.onPagesChanged?.call(pages);
  }

  Widget _buildDropdown(
      AppLocalizations loc, bool isAnonymous, String selected) {
    final pageTitles = _getPageTitles(loc, isAnonymous);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        style: const TextStyle(
          color: Colors.white, 
        ),
        dropdownColor: Color(0xFF0066CC), 
        iconEnabledColor: Colors.white, 
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
      case 'personal_event':
        return const PageA();
      case 'settings':
        return const PageA();
      case 'recommended_event':
        return const PageRecommendedEvent();
      case 'recommended_attractions':
        return const PageA();
      case 'memory_trace':
        return const PageA();
      case 'account_records':
        return const PageA();
      case 'points_record':
        return const PageA();
      case 'game':
        return const PageA();
      case 'ai':
        return const PageA();
      default:
        return const SizedBox.shrink();
    }
  }

  Map<String, String> _getPageTitles(AppLocalizations loc, bool isAnonymous) {
    return isAnonymous
      ? {
          'recommended_event': loc.recommended_event,
          'recommended_attractions': loc.recommended_attractions,
        }
      : {
          'personal_event': loc.personal_event,
          'settings': loc.settings,
          'recommended_event': loc.recommended_event,
          'recommended_attractions': loc.recommended_attractions,
          'memory_trace': loc.memory_trace,
          'account_records': loc.account_records,
          'points_record': loc.points_record,
          'game': loc.game,
          'ai': loc.ai,
        };
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedPage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox.expand(
        child: Padding(
      padding: kGapEI12,
      child: _buildSelectedPage(),
    ));
  }
}
