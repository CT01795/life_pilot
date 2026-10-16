// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/utils/logger.dart';

/// Each element belongs to its own State; no global factory captures old States.
class WidgetsBlocklyWebEditor extends StatefulWidget {
  final ModelBlocklyMessageQueue messages;
  final ValueChanged<Map<String, dynamic>> onCommandsJson;
  const WidgetsBlocklyWebEditor({
    super.key,
    required this.messages,
    required this.onCommandsJson,
  });

  @override
  State<WidgetsBlocklyWebEditor> createState() =>
      WidgetsBlocklyWebEditorState();
}

class WidgetsBlocklyWebEditorState extends State<WidgetsBlocklyWebEditor> {
  // WindowProxy wrappers are not reliable identity keys in dart:html.
  // Correlate replies with this editor instead of comparing those wrappers.
  final String _bridgeId = List.generate(
    4,
    (_) => Random.secure().nextInt(0x100000000).toRadixString(16),
  ).join('-');
  html.IFrameElement? _frame;
  StreamSubscription<html.Event>? _loadSubscription;
  StreamSubscription<html.MessageEvent>? _messageSubscription;

  @visibleForTesting
  html.IFrameElement? get frame => _frame;

  @override
  void initState() {
    super.initState();
    _messageSubscription = html.window.onMessage.listen(_onMessage);
  }

  void _onElementCreated(Object element) {
    if (!mounted) return;
    final frame = element as html.IFrameElement;
    _loadSubscription?.cancel();
    _frame = frame;
    widget.messages.attach((message) {
      frame.contentWindow?.postMessage({
        ...message,
        'bridgeId': _bridgeId,
      }, html.window.location.origin);
    });
    _loadSubscription = frame.onLoad.listen((_) {
      if (mounted && identical(_frame, frame)) widget.messages.markReady();
    });
    frame
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..src = 'assets/assets/blockly/index.html';
  }

  void _onMessage(html.MessageEvent event) {
    final frame = _frame;
    if (!mounted ||
        frame == null ||
        event.origin != html.window.location.origin ||
        event.data is! String) {
      return;
    }
    try {
      final message = jsonDecode(event.data as String);
      if (message is! Map || message['type'] != 'commands_ready') return;
      if (message['bridgeId'] != _bridgeId) return;
      final encoded = message['json'];
      if (encoded is! String) {
        throw const FormatException('Missing commands JSON');
      }
      final commands = jsonDecode(encoded);
      if (commands is! Map<String, dynamic>) {
        throw const FormatException('Invalid commands JSON');
      }
      if (!widget.messages.completeRequest()) return;
      widget.onCommandsJson(commands);
    } catch (error, stackTrace) {
      logger.e(
        'Unable to read Blockly commands',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'iframe',
    onElementCreated: _onElementCreated,
  );

  @override
  void dispose() {
    _loadSubscription?.cancel();
    _messageSubscription?.cancel();
    widget.messages.dispose();
    _frame = null;
    super.dispose();
  }
}
