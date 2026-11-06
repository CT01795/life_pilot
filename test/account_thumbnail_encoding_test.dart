import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:life_pilot/accounting/model_account_thumbnail.dart';
import 'package:life_pilot/accounting/repository_account_image.dart';

AccountThumbnailPixels pixels(
  int width,
  int height, {
  bool transparent = false,
}) {
  final random = Random(42);
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < rgba.length; i += 4) {
    rgba[i] = random.nextInt(256);
    rgba[i + 1] = random.nextInt(256);
    rgba[i + 2] = random.nextInt(256);
    rgba[i + 3] = transparent ? random.nextInt(256) : 255;
  }
  return (rgba: rgba, width: width, height: height);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'repository compresses complex originals without changing original bytes',
    () async {
      final source = pixels(320, 320);
      final bitmap = image.Image.fromBytes(
        width: 320,
        height: 320,
        bytes: source.rgba.buffer,
        numChannels: 4,
      );
      final original = image.encodePng(bitmap);
      final fields = await RepositoryAccountImage.imageFields(original);
      expect(fields['master_graph_url'], base64Encode(original));
      final encoded = fields['thumbnail_base64'] as String;
      expect(encoded, startsWith('/9j/'));
      expect(
        base64Decode(encoded).length,
        lessThanOrEqualTo(ModelAccountThumbnail.maxBytes),
      );
      expect(ModelAccountThumbnail.longestEdge(encoded), 320);
    },
  );
  for (final size in [(320, 320), (320, 200), (200, 320)]) {
    test('complex opaque image keeps resolution within 48 KiB: $size', () {
      final source = pixels(size.$1, size.$2);
      final original = image.Image.fromBytes(
        width: source.width,
        height: source.height,
        bytes: source.rgba.buffer,
        numChannels: 4,
      );
      expect(
        image.encodePng(original).length,
        greaterThan(ModelAccountThumbnail.maxBytes),
      );
      final encoded = ModelAccountThumbnail.encode(source)!;
      final bytes = base64Decode(encoded);
      expect(bytes.length, lessThanOrEqualTo(ModelAccountThumbnail.maxBytes));
      expect(encoded.length, lessThanOrEqualTo(65536));
      expect(encoded, startsWith('/9j/'));
      final decoded = image.decodeJpg(bytes)!;
      expect((decoded.width, decoded.height), size);
      expect(ModelAccountThumbnail.longestEdge(encoded), 320);
    });
  }
  test('small transparent graphics preserve PNG pixels and alpha', () {
    final rgba = Uint8List(24 * 16 * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 100;
      rgba[i + 1] = 80;
      rgba[i + 2] = 60;
      rgba[i + 3] = i % 8 == 0 ? 0 : 128;
    }
    final encoded = ModelAccountThumbnail.encode((
      rgba: rgba,
      width: 24,
      height: 16,
    ))!;
    expect(encoded, startsWith('iVBORw0KGgo'));
    final decoded = image.decodePng(base64Decode(encoded))!;
    expect((decoded.width, decoded.height), (24, 16));
    expect(decoded.getPixel(0, 0).a, 0);
    expect(decoded.getPixel(1, 0).a, 128);
    expect(ModelAccountThumbnail.longestEdge(encoded), 24);
  });
  test(
    'oversized transparent noise never becomes a tiny or flattened JPEG',
    () {
      final encoded = ModelAccountThumbnail.encode(
        pixels(320, 320, transparent: true),
      );
      if (encoded != null) {
        expect(encoded, startsWith('iVBORw0KGgo'));
        expect(
          base64Decode(encoded).length,
          lessThanOrEqualTo(ModelAccountThumbnail.maxBytes),
        );
        expect(
          ModelAccountThumbnail.longestEdge(encoded),
          greaterThanOrEqualTo(256),
        );
      }
    },
  );
  test('invalid headers and pixel buffers fail safely', () {
    for (final value in [
      null,
      '',
      'invalid',
      '/9j/',
      base64Encode([255, 216, 255, 192, 0, 0]),
    ]) {
      expect(ModelAccountThumbnail.longestEdge(value), isNull);
    }
    expect(
      () => ModelAccountThumbnail.encode((
        rgba: Uint8List(3),
        width: 1,
        height: 1,
      )),
      throwsFormatException,
    );
  });
}
