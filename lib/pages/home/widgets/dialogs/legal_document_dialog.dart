import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

class LegalDocumentDialog extends StatefulWidget {
  const LegalDocumentDialog({
    super.key,
    required this.assetPath,
    this.onReadComplete,
  });

  final String assetPath;
  final VoidCallback? onReadComplete;

  @override
  State<LegalDocumentDialog> createState() => _LegalDocumentDialogState();
}

class _LegalDocumentDialogState extends State<LegalDocumentDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _hasReportedReadComplete = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkReadComplete);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _checkReadComplete() {
    if (_hasReportedReadComplete || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 8) return;
    _reportReadComplete();
  }

  void _checkFullyVisibleDocument() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.maxScrollExtent == 0) {
      _reportReadComplete();
    }
  }

  void _reportReadComplete() {
    if (_hasReportedReadComplete || !mounted) return;
    setState(() => _hasReportedReadComplete = true);
    widget.onReadComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
      title: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          icon: const Icon(Icons.close),
          tooltip: loc.close,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 520),
        child: FutureBuilder<String>(
          future: rootBundle.loadString(widget.assetPath),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Unable to load this document.'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _checkFullyVisibleDocument(),
            );
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: HtmlWidget(snapshot.data!),
                  ),
                ),
                if (_hasReportedReadComplete)
                  Padding(
                    padding: Insets.directionalT6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        Gaps.w8,
                        Text(
                          loc.legalDocumentReadComplete,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc.close),
        ),
      ],
    );
  }
}
