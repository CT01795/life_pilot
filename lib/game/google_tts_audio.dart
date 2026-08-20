import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import '../utils/logger.dart';

class GoogleTtsAudio {
  GoogleTtsAudio({
    AudioPlayer? player,
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 10),
    this.playbackTimeout = const Duration(minutes: 2),
  })  : _player = player ?? AudioPlayer(),
        _client = client ?? http.Client();

  final AudioPlayer _player;
  final http.Client _client;
  final Duration requestTimeout;
  final Duration playbackTimeout;
  final Map<String, Uint8List> _cache = {};
  final Set<String> _activeRequests = {};
  bool _disposed = false;

  Future<void> speak({
    required String text,
    required String languageCode,
  }) async {
    final spokenText = text.split('/').first.trim();
    if (_disposed || spokenText.isEmpty) return;

    final cacheKey = '$languageCode\u0000$spokenText';
    if (!_activeRequests.add(cacheKey)) return;

    try {
      final bytes = _cache[cacheKey] ??
          await _download(spokenText, languageCode, cacheKey);
      if (bytes == null || _disposed) return;

      final playbackComplete = _player.onPlayerComplete.first;
      await _player.play(BytesSource(bytes));
      await playbackComplete.timeout(
        playbackTimeout,
        onTimeout: () {},
      );
    } on TimeoutException catch (error, stackTrace) {
      logger.w(
        'Google TTS timed out',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      logger.e(
        'Google TTS failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _activeRequests.remove(cacheKey);
    }
  }

  Future<Uint8List?> _download(
    String text,
    String languageCode,
    String cacheKey,
  ) async {
    final url = Uri.https(
      'translate.google.com',
      '/translate_tts',
      {
        'ie': 'UTF-8',
        'tl': languageCode,
        'client': 'tw-ob',
        'q': text,
      },
    );
    final response = await _client.get(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 Chrome/115 Safari/537.36',
        'Referer': url.toString(),
      },
    ).timeout(requestTimeout);

    if (response.statusCode != 200) {
      logger.e('Google TTS error: ${response.statusCode}');
      return null;
    }

    _cache[cacheKey] = response.bodyBytes;
    return response.bodyBytes;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _activeRequests.clear();
    _client.close();
    await _player.dispose();
  }
}
