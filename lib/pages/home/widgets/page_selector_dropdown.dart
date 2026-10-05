import 'package:flutter/material.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:provider/provider.dart';

class PageSelectorDropdown extends StatelessWidget {
  const PageSelectorDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Consumer<ControllerPageMain>(
      builder: (context, controller, _) {
        final pages = controller.availablePages;

        if (pages.isEmpty) {
          return const SizedBox.shrink();
        }

        return DropdownButtonHideUnderline(
          child: DropdownButton<PageType>(
            isExpanded: true,
            value: pages.contains(controller.selectedPage)
                ? controller.selectedPage
                : pages.first,
            style: const TextStyle(color: Colors.white),
            dropdownColor: const Color(0xFF0066CC),
            iconEnabledColor: Colors.white,
            selectedItemBuilder: (context) {
              return pages.map((page) {
                final title = page.title(loc: loc);
                return Tooltip(
                  message: title,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList();
            },
            items: pages.map((page) {
              return DropdownMenuItem(
                value: page,
                child: Text(
                  page.title(loc: loc),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) controller.changePage(value);
            },
          ),
        );
      },
    );
  }
}
