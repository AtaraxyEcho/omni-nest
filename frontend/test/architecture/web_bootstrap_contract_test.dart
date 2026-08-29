import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Web bootstrap only uses supported Flutter template tokens', () {
    final indexSource = File('web/index.html').readAsStringSync();
    final bootstrapSource = File('web/flutter_bootstrap.js').readAsStringSync();
    final tokens = RegExp(r'\{\{([^}]+)\}\}')
        .allMatches('$indexSource\n$bootstrapSource')
        .map((match) => match.group(1));

    expect(
      tokens,
      everyElement(
        isIn(const <String>{
          'flutter_js',
          'flutter_build_config',
          'flutter_service_worker_version',
        }),
      ),
    );
    expect(indexSource, isNot(contains('flutter_bootstrap_config')));
  });

  test('Web bootstrap loads the bundled Chromium CanvasKit runtime', () {
    final bootstrapSource = File('web/flutter_bootstrap.js').readAsStringSync();

    expect(bootstrapSource, contains('{{flutter_js}}'));
    expect(bootstrapSource, contains('{{flutter_build_config}}'));
    expect(
      bootstrapSource,
      contains("canvasKitBaseUrl: '/canvaskit/chromium/'"),
    );
    expect(File('web/canvaskit/chromium/canvaskit.js').existsSync(), isTrue);
    expect(File('web/canvaskit/chromium/canvaskit.wasm').existsSync(), isTrue);
  });
}
