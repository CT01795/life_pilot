import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as image;

typedef AccountThumbnailPixels = ({Uint8List rgba, int width, int height});

/// Encoding policy for already downsampled pixels; never decodes full originals.
class ModelAccountThumbnail {
  static const edge = 320;
  static const maxBytes = 49152;

  static String? encode(AccountThumbnailPixels pixels) {
    final (:rgba, :width, :height) = pixels;
    if (width < 1 ||
        height < 1 ||
        width > edge ||
        height > edge ||
        rgba.length != width * height * 4) {
      throw const FormatException('Invalid thumbnail pixels');
    }
    final bitmap = image.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: image.ChannelOrder.rgba,
    );
    // Icons and text retain their exact pixels when lossless PNG fits.
    final png = image.encodePng(bitmap);
    if (png.length <= maxBytes) return base64Encode(png);
    var transparent = false;
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 255) {
        transparent = true;
        break;
      }
    }
    if (transparent) {
      // Never flatten transparency or fall back to tiny 64/96-pixel covers.
      final longest = width > height ? width : height;
      if (longest > 256) {
        final smaller = image.copyResize(
          bitmap,
          width: width >= height ? 256 : null,
          height: height > width ? 256 : null,
          interpolation: image.Interpolation.average,
        );
        final encoded = image.encodePng(smaller);
        if (encoded.length <= maxBytes) return base64Encode(encoded);
      }
      return null;
    }
    // Photos keep their dimensions; reduce JPEG quality before any resolution.
    for (final quality in [90, 85, 80, 75, 70, 65, 60, 55]) {
      final jpg = image.encodeJpg(
        bitmap,
        quality: quality,
        chroma: image.JpegChroma.yuv420,
      );
      if (jpg.length <= maxBytes) return base64Encode(jpg);
    }
    return null;
  }

  /// Header-only size check, also understands historical PNG thumbnails.
  static int? longestEdge(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.length >= 24 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71) {
        final data = ByteData.sublistView(bytes);
        final width = data.getUint32(16), height = data.getUint32(20);
        return width > height ? width : height;
      }
      if (bytes.length < 4 || bytes[0] != 255 || bytes[1] != 216) return null;
      var offset = 2;
      while (offset + 3 < bytes.length) {
        if (bytes[offset++] != 255) return null;
        while (offset < bytes.length && bytes[offset] == 255) {
          offset++;
        }
        if (offset >= bytes.length) return null;
        final marker = bytes[offset++];
        if (marker == 218 || marker == 217) return null;
        if (marker == 1 || (marker >= 208 && marker <= 215)) continue;
        if (offset + 1 >= bytes.length) return null;
        final length = (bytes[offset] << 8) | bytes[offset + 1];
        if (length < 2 || offset + length > bytes.length) return null;
        if (marker == 192 || marker == 193 || marker == 194) {
          if (length < 7) return null;
          final height = (bytes[offset + 3] << 8) | bytes[offset + 4];
          final width = (bytes[offset + 5] << 8) | bytes[offset + 6];
          return width > height ? width : height;
        }
        offset += length;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
