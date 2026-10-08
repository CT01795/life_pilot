import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/const.dart';

class DataStorageChoice extends StatelessWidget {
  const DataStorageChoice({
    required this.value,
    required this.onChanged,
    this.localEnabled = true,
    this.localSubscriptionActive = true,
    this.localPromotionAccess = false,
    super.key,
  });

  final DataStorageLocation value;
  final ValueChanged<DataStorageLocation>? onChanged;
  final bool localEnabled;
  final bool localSubscriptionActive;
  final bool localPromotionAccess;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.dataStorageTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Gaps.h8,
            _StorageOption(
              icon: Icons.cloud_outlined,
              label: loc.dataStorageCloud,
              description: loc.dataStorageCloudWarning,
              selected: value == DataStorageLocation.cloud,
              enabled: onChanged != null,
              onTap: () => onChanged?.call(DataStorageLocation.cloud),
            ),
            Gaps.h8,
            _StorageOption(
              icon: Icons.devices_outlined,
              label: loc.dataStorageLocal,
              description: loc.dataStorageLocalWarning,
              subtitle: localSubscriptionActive
                  ? null
                  : localPromotionAccess
                  ? loc.dataStorageLocalPromotionNoSubscription
                  : loc.localSubscriptionRequiredForChanges,
              selected: value == DataStorageLocation.local,
              enabled: onChanged != null && localEnabled,
              onTap: () => onChanged?.call(DataStorageLocation.local),
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageOption extends StatelessWidget {
  const _StorageOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.subtitle,
    this.description,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final String? subtitle;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.secondaryContainer
          : colors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? colors.secondary : colors.outlineVariant,
        ),
      ),
      child: ListTile(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        leading: Icon(icon),
        title: Text(label, maxLines: 2),
        subtitle: (subtitle == null && description == null)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null) Text(description!),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: TextStyle(color: colors.error)),
                  ],
                ],
              ),
        trailing: selected
            ? Icon(Icons.check_circle, color: colors.secondary)
            : const Icon(Icons.circle_outlined),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
