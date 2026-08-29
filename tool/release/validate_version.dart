import 'dart:io';

import 'release_version.dart';

void main(List<String> arguments) {
  try {
    final tag = _readTag(arguments);
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = parsePubspecVersion(pubspec);
    final existingTags = _git('tag', '--list', 'v*')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final currentTag = _currentCheckoutTag();
    validateReleaseTag(
      version,
      tag,
      existingTags: existingTags,
      isCurrentTag: currentTag == tag,
    );
    final previousVersions = <ReleaseVersion>[];
    for (final existingTag in existingTags) {
      if (existingTag == currentTag) continue;
      final previousPubspec = _gitOutput(<String>[
        'show',
        '$existingTag:pubspec.yaml',
      ]);
      try {
        previousVersions.add(parsePubspecVersion(previousPubspec));
      } on FormatException catch (error) {
        throw FormatException(
          'Cannot inspect version from tag $existingTag: $error',
        );
      }
    }
    validateReleaseBuildNumber(version, previousVersions);
    stdout.writeln('Release version $version validated for tag $tag.');
  } on Object catch (error) {
    stderr.writeln('Release version validation failed: $error');
    exitCode = 1;
  }
}

String _readTag(List<String> arguments) {
  final index = arguments.indexOf('--tag');
  if (index >= 0 && index + 1 < arguments.length) {
    return arguments[index + 1];
  }
  final refType = Platform.environment['GITHUB_REF_TYPE'];
  final refName = Platform.environment['GITHUB_REF_NAME'];
  if (refType == 'tag' && refName != null && refName.isNotEmpty) {
    return refName;
  }
  final currentTag = _currentCheckoutTag();
  if (currentTag.isEmpty) {
    throw const FormatException(
      'No release tag found. Pass --tag v<version> locally or run from a tag workflow.',
    );
  }
  return currentTag;
}

String _currentCheckoutTag() {
  final result = Process.runSync('git', const [
    'describe',
    '--exact-match',
    '--tags',
    'HEAD',
  ], runInShell: true);
  if (result.exitCode != 0) return '';
  return '${result.stdout}'.trim();
}

String _git(String command, String argument, String pattern) {
  return _gitOutput(<String>[command, argument, pattern]);
}

String _gitOutput(List<String> arguments) {
  final result = Process.runSync('git', <String>[
    ...arguments,
  ], runInShell: true);
  if (result.exitCode != 0) {
    throw ProcessException('git', arguments, result.stderr, result.exitCode);
  }
  return '${result.stdout}';
}
