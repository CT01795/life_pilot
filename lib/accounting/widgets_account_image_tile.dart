import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';

class AccountImageTile extends StatelessWidget {
  const AccountImageTile({
    required this.name,
    required this.loadImage,
    required this.changeImage,
    this.imageBytes,
    super.key,
  });
  final String name;
  final Uint8List? imageBytes;
  final Future<Uint8List?> Function() loadImage;
  final VoidCallback changeImage;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context).width < 400 ? 84.0 : 120.0;
    return SizedBox.square(
      dimension: size,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Tooltip(
              message: loc.previewAccountImage,
              child: InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _AccountImagePreview(
                    name: name,
                    loadImage: () => imageBytes == null
                        ? loadImage()
                        : Future.value(imageBytes),
                  ),
                ),
                child: imageBytes == null
                    ? Center(
                        child: Text(
                          name.isEmpty ? '' : name.characters.first,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      )
                    : Image.memory(imageBytes!, fit: BoxFit.cover),
              ),
            ),
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: IconButton.filledTonal(
                tooltip: loc.changeAccountImage,
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: changeImage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountImagePreview extends StatefulWidget {
  const _AccountImagePreview({required this.name, required this.loadImage});
  final String name;
  final Future<Uint8List?> Function() loadImage;

  @override
  State<_AccountImagePreview> createState() => _AccountImagePreviewState();
}

class _AccountImagePreviewState extends State<_AccountImagePreview> {
  late Future<Uint8List?> _image = widget.loadImage();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.name),
      content: FutureBuilder<Uint8List?>(
        future: _image,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return WidgetsLoadError(
              onRetry: () => setState(() => _image = widget.loadImage()),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) return Text(loc.noData);
          return Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Text(loc.noData),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.close),
        ),
      ],
    );
  }
}
