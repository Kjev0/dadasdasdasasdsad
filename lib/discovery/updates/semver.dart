import 'package:flutter/foundation.dart';

/// Semantic version (https://semver.org) with SemVer 2.0 precedence.
///
/// Lenient parsing for release tags: a leading `v`/`V` is ignored,
/// `1.2` means `1.2.0`, and Flutter's `+build` suffix is ignored for
/// ordering (build metadata never affects precedence).
@immutable
class SemVer implements Comparable<SemVer> {
  const SemVer(this.major, this.minor, this.patch, {this.preRelease = const [], this.build});

  final int major;
  final int minor;
  final int patch;

  /// Dot-separated pre-release identifiers (`1.0.0-beta.2` → `[beta, 2]`).
  final List<String> preRelease;
  final String? build;

  bool get isPreRelease => preRelease.isNotEmpty;

  static final _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$',
  );

  /// Null when [input] is not a version.
  static SemVer? tryParse(String input) {
    final m = _pattern.firstMatch(input.trim());
    if (m == null) return null;
    final pre = m.group(4);
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2) ?? '0'),
      int.parse(m.group(3) ?? '0'),
      preRelease: pre == null ? const [] : pre.split('.').where((s) => s.isNotEmpty).toList(),
      build: m.group(5),
    );
  }

  static SemVer parse(String input) =>
      tryParse(input) ?? (throw FormatException('Not a semantic version', input));

  @override
  int compareTo(SemVer other) {
    for (final c in [major.compareTo(other.major), minor.compareTo(other.minor), patch.compareTo(other.patch)]) {
      if (c != 0) return c;
    }
    // A release ranks above its pre-releases.
    if (preRelease.isEmpty || other.preRelease.isEmpty) {
      return (preRelease.isEmpty ? 1 : 0) - (other.preRelease.isEmpty ? 1 : 0);
    }
    for (var i = 0; i < preRelease.length && i < other.preRelease.length; i++) {
      final c = _compareIdentifier(preRelease[i], other.preRelease[i]);
      if (c != 0) return c;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  /// Numeric identifiers compare numerically and rank below alphanumeric.
  static int _compareIdentifier(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  }

  bool operator >(SemVer other) => compareTo(other) > 0;

  bool operator <(SemVer other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() => '$major.$minor.$patch${preRelease.isEmpty ? '' : '-${preRelease.join('.')}'}'
      '${build == null ? '' : '+$build'}';
}
