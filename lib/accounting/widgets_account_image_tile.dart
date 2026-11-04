import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';

class AccountImageTile extends StatefulWidget {
  const AccountImageTile({
    required this.name,
    required this.loadImage,
    this.changeImage,
    this.loadThumbnail,
    this.imageBytes,
    super.key,
  });
  final String name;
  final Uint8List? imageBytes;
  final Future<Uint8List?> Function() loadImage;
  final VoidCallback? changeImage;
  final Future<Uint8List?> Function()? loadThumbnail;

  @override
  State<AccountImageTile> createState() => _AccountImageTileState();
}

class _AccountImageTileState extends State<AccountImageTile> {
  Future<Uint8List?>? _original;
  late Future<Uint8List?> _cover = _loadCover();

  Future<Uint8List?> _loadOriginal() async {
    if (widget.imageBytes case final bytes?) return bytes;
    final request = _original ??= Future.sync(widget.loadImage);
    try {
      return await request;
    } catch (_) {
      if (identical(_original, request)) _original = null;
      rethrow;
    }
  }

  Future<Uint8List?> _loadCover() async {
    if (widget.imageBytes case final bytes?) return bytes;
    final thumbnail = await widget.loadThumbnail?.call();
    if (thumbnail != null || !mounted) return thumbnail;
    // Older accounts may only have an original. Reuse it in the preview.
    return _loadOriginal();
  }

  @override
  void didUpdateWidget(covariant AccountImageTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.imageBytes, widget.imageBytes)) {
      _original = null;
      _cover = _loadCover();
    }
  }

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
                    name: widget.name,
                    loadImage: _loadOriginal,
                  ),
                ),
                child: FutureBuilder<Uint8List?>(
                  future: _cover,
                  builder: (context, snapshot) {
                    final bytes = widget.imageBytes ?? snapshot.data;
                    final placeholder = Center(
                      child: Text(
                        widget.name.isEmpty ? '' : widget.name.characters.first,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    );
                    return bytes == null
                        ? placeholder
                        : Image.memory(
                            bytes,
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            errorBuilder: (_, _, _) => placeholder,
                          );
                  },
                ),
              ),
            ),
            if (widget.changeImage != null)
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: IconButton.filledTonal(
                  tooltip: loc.changeAccountImage,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: widget.changeImage,
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
