import 'package:flutter_test/flutter_test.dart';
import '../../../tool/release/release_version.dart';

void main() {
  group('parsePubspecVersion', () {
    test('parses semantic name and numeric build', () {
      final version = parsePubspecVersion('''
name: three_lines
version: 1.2.3+6
''');

      expect(version.name, '1.2.3');
      expect(version.build, 6);
      expect(version.tag, 'v1.2.3');
    });

    test('rejects missing or malformed version', () {
      expect(
        () => parsePubspecVersion('name: three_lines\n'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePubspecVersion('version: 1.2.3'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => parsePubspecVersion('version: 1.2+zero'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('validateReleaseTag', () {
    const version = ReleaseVersion(name: '1.2.3', build: 6);

    test('accepts matching tag when it is the current checkout tag', () {
      expect(
        () => validateReleaseTag(
          version,
          'v1.2.3',
          existingTags: const ['v1.2.2', 'v1.2.3'],
          isCurrentTag: true,
        ),
        returnsNormally,
      );
    });

    test('rejects a tag that does not match pubspec version', () {
      expect(
        () => validateReleaseTag(version, 'v1.2.4'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects reusing an existing tag before release creation', () {
      expect(
        () => validateReleaseTag(
          version,
          'v1.2.3',
          existingTags: const ['v1.2.2', 'v1.2.3'],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects non-tag release references', () {
      expect(
        () => validateReleaseTag(version, '1.2.3'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('validateReleaseBuildNumber', () {
    test('rejects a build number reused or lower than a previous tag', () {
      expect(
        () => validateReleaseBuildNumber(
          const ReleaseVersion(name: '1.2.3', build: 6),
          const [ReleaseVersion(name: '1.2.2', build: 6)],
        ),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => validateReleaseBuildNumber(
          const ReleaseVersion(name: '1.2.3', build: 5),
          const [ReleaseVersion(name: '1.2.2', build: 6)],
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('accepts a strictly increasing build number', () {
      expect(
        () => validateReleaseBuildNumber(
          const ReleaseVersion(name: '1.2.3', build: 6),
          const [ReleaseVersion(name: '1.2.2', build: 5)],
        ),
        returnsNormally,
      );
    });
  });
}
