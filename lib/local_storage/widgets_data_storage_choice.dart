import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';

class DataStorageChoice extends StatelessWidget {
  const DataStorageChoice(
      {required this.value, required this.onChanged, super.key});

  final DataStorageLocation value;
  final ValueChanged<DataStorageLocation>? onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isLocal = value == DataStorageLocation.local;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.dataStorageTitle,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _StorageOption(
              icon: Icons.cloud_outlined,
              label: loc.dataStorageCloud,
              selected: value == DataStorageLocation.cloud,
              enabled: onChanged != null,
              onTap: () => onChanged?.call(DataStorageLocation.cloud),
            ),
            const SizedBox(height: 6),
            _StorageOption(
              icon: Icons.devices_outlined,
              label: loc.dataStorageLocal,
              selected: value == DataStorageLocation.local,
              enabled: onChanged != null,
              onTap: () => onChanged?.call(DataStorageLocation.local),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isLocal ? Icons.info_outline : Icons.cloud_done_outlined,
                    size: 18, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isLocal
                        ? loc.dataStorageLocalWarning
                        : loc.dataStorageCloudWarning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
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
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color:
          selected ? colors.secondaryContainer : colors.surfaceContainerLowest,
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
        trailing: selected
            ? Icon(Icons.check_circle, color: colors.secondary)
            : const Icon(Icons.circle_outlined),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
