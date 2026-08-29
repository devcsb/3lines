// Version parsing and tag validation shared by local and CI release checks.

class ReleaseVersion {
  const ReleaseVersion({required this.name, required this.build});

  final String name;
  final int build;

  String get tag => 'v$name';

  @override
  String toString() => '$name+$build';
}

ReleaseVersion parsePubspecVersion(String pubspecContents) {
  final match = RegExp(
    r'^\s*version:\s*([0-9]+(?:\.[0-9]+){2}(?:-[0-9A-Za-z.-]+)?)\+(\d+)\s*(?:#.*)?$',
    multiLine: true,
  ).firstMatch(pubspecContents);
  if (match == null) {
    throw const FormatException(
      'pubspec.yaml must contain a version in name+build format, for example 1.2.3+6',
    );
  }

  final build = int.tryParse(match.group(2)!);
  if (build == null) {
    throw const FormatException(
      'pubspec version build must be a non-negative integer',
    );
  }
  return ReleaseVersion(name: match.group(1)!, build: build);
}

void validateReleaseTag(
  ReleaseVersion version,
  String tag, {
  Iterable<String> existingTags = const <String>[],
  bool isCurrentTag = false,
}) {
  if (tag != version.tag) {
    throw FormatException(
      'Release tag $tag does not match pubspec version ${version.toString()}; expected ${version.tag}',
    );
  }
  if (!isCurrentTag && existingTags.contains(tag)) {
    throw FormatException(
      'Release tag $tag already exists. Bump pubspec.yaml version before creating a release.',
    );
  }
}

void validateReleaseBuildNumber(
  ReleaseVersion version,
  Iterable<ReleaseVersion> previousVersions,
) {
  final previous = previousVersions.toList(growable: false);
  final highestBuild = previous.fold<int?>(
    null,
    (highest, candidate) => highest == null || candidate.build > highest
        ? candidate.build
        : highest,
  );
  if (highestBuild != null && version.build <= highestBuild) {
    throw FormatException(
      'Build number ${version.build} must be greater than the highest previous build $highestBuild',
    );
  }
}
