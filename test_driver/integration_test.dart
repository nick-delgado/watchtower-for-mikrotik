import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Runs integration tests with `flutter drive` and saves the screenshots
/// they take to `build/screenshots/`.
Future<void> main() => integrationDriver(
  onScreenshot: (name, image, [_]) async {
    File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(image);
    return true;
  },
);
