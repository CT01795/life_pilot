import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Native bridge shared by Scratch and Scratch Maze.
class WidgetsBlocklyNativeEditor extends StatefulWidget {
  const WidgetsBlocklyNativeEditor({
    super.key,
    required this.messages,
    required this.onCommandsJson,
  });

  final ModelBlocklyMessageQueue messages;
  final ValueChanged<Map<String, dynamic>> onCommandsJson;

  @override
  State<WidgetsBlocklyNativeEditor> createState() =>
      _WidgetsBlocklyNativeEditorState();
}

class _WidgetsBlocklyNativeEditorState
    extends State<WidgetsBlocklyNativeEditor> {
  late final WebViewController _controller;
  Future<void> _scripts = Future<void>.value();
  int _generation = 0;
  bool _loading = true;
  bool _failed = false;
  bool _channelConfigured = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _attach();
    unawaited(_initialize());
  }

  void _attach() {
    final generation = ++_generation;
    widget.messages.attach((message) {
      // Preserve max-blocks -> start ordering even though JavaScript is async.
      _scripts = _scripts.then((_) async {
        if (!mounted || generation != _generation || _failed) return;
        final script = message['type'] == 'set_max_blocks'
            ? 'setMaxBlocksFromFlutter(${message['maxBlocks']})'
            : 'sendCommandsToFlutter()';
        try {
          await _controller.runJavaScript(script);
        } catch (error, stackTrace) {
          if (mounted && generation == _generation) {
            widget.messages.completeRequest();
            _showFailure(error, stackTrace);
          }
        }
      });
    });
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!mounted) return;
      if (!_channelConfigured) {
        await _controller.addJavaScriptChannel(
          'BlocklyCallback',
          onMessageReceived: _onCommands,
        );
        _channelConfigured = true;
      }
      if (!mounted) return;
      // Configure callbacks BEFORE starting the asset load.
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            _attach();
            setState(() {
              _loading = true;
              _failed = false;
            });
          },
          onPageFinished: (_) => unawaited(_onReady()),
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _showFailure(error, StackTrace.current);
            }
          },
        ),
      );
      if (!mounted) return;
      await _controller.loadFlutterAsset('assets/blockly/index.html');
    } catch (error, stackTrace) {
      _showFailure(error, stackTrace);
    }
  }

  Future<void> _onReady() async {
    final generation = _generation;
    try {
      final ready = await _controller.runJavaScriptReturningResult(
        'typeof window.sendCommandsToFlutter === "function" && '
        'typeof window.setMaxBlocksFromFlutter === "function"',
      );
      if (!mounted || generation != _generation) return;
      if (ready != true && ready != 'true') {
        throw StateError('Blockly scripts did not initialize');
      }
      setState(() {
        _loading = false;
        _failed = false;
      });
      widget.messages.markReady();
    } catch (error, stackTrace) {
      if (mounted && generation == _generation) {
        _showFailure(error, stackTrace);
      }
    }
  }

  void _onCommands(JavaScriptMessage message) {
    if (!mounted || _loading || _failed) return;
    try {
      final commands = jsonDecode(message.message);
      if (commands is! Map<String, dynamic> || commands['xml'] is! String) {
        throw const FormatException('Invalid Blockly commands');
      }
      if (!widget.messages.completeRequest()) return;
      widget.onCommandsJson(commands);
    } catch (error, stackTrace) {
      widget.messages.completeRequest();
      _showFailure(error, stackTrace);
    }
  }

  void _showFailure(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    logger.e(
      'Native Blockly editor failed',
      error: error,
      stackTrace: stackTrace,
    );
    setState(() {
      _loading = false;
      _failed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(
          controller: _controller,
          // Block drags belong to Blockly, not the surrounding scroll views.
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
          },
        ),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_failed)
          ColoredBox(
            color: Theme.of(context).colorScheme.surface,
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  _attach();
                  setState(() {
                    _loading = true;
                    _failed = false;
                  });
                  unawaited(_initialize());
                },
                icon: const Icon(Icons.refresh),
                label: Text('${loc.unknownError} · ${loc.retry}'),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _generation++;
    widget.messages.dispose();
    super.dispose();
  }
}
