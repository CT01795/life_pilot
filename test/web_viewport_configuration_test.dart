import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web viewport keeps keyboard resizing aligned with Flutter', () {
    final indexHtml = File('web/index.html').readAsStringSync();

    expect(indexHtml, contains('name="viewport"'));
    expect(indexHtml, contains('interactive-widget=resizes-content'));
    expect(indexHtml, contains('viewport-fit=cover'));
  });
}
