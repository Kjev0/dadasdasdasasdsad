// Merges ARB fragments into the ARB files consumed by `flutter gen-l10n`.
//
// Each feature area owns `lib/l10n/fragments/<area>_<locale>.arb`
// (e.g. `player_en.arb`, `player_da.arb`) so several people can add strings
// without editing one huge file. This tool:
//   * merges all fragments per locale into lib/l10n/arb/app_<locale>.arb
//   * fails on duplicate keys across fragments
//   * fails when a key exists in English but not in another locale (parity)
//
// Usage: dart run tool/merge_arb.dart && flutter gen-l10n
import 'dart:convert';
import 'dart:io';

const fragmentsDir = 'lib/l10n/fragments';
const outDir = 'lib/l10n/arb';
const templateLocale = 'en';

void main(List<String> args) {
  final dir = Directory(fragmentsDir);
  if (!dir.existsSync()) {
    stderr.writeln('No $fragmentsDir directory');
    exit(1);
  }
  final pattern = RegExp(r'^([a-z0-9_]+)_([a-z]{2}(?:_[A-Z]{2})?)\.arb$');
  final merged = <String, Map<String, Object?>>{};
  final owner = <String, Map<String, String>>{};
  final errors = <String>[];

  final files = dir.listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final m = pattern.firstMatch(name);
    if (m == null) {
      errors.add('Bad fragment file name: $name (expected <area>_<locale>.arb)');
      continue;
    }
    final area = m.group(1)!;
    final locale = m.group(2)!;
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      errors.add('$name: invalid JSON: ${e.message}');
      continue;
    }
    if (decoded is! Map) {
      errors.add('$name: not a JSON object');
      continue;
    }
    final target = merged.putIfAbsent(locale, () => {'@@locale': locale});
    final owners = owner.putIfAbsent(locale, () => {});
    for (final entry in decoded.entries) {
      final key = entry.key as String;
      if (key.startsWith('@@')) continue;
      if (target.containsKey(key)) {
        errors.add('Duplicate key "$key" in $name (already defined by ${owners[key]})');
        continue;
      }
      target[key] = entry.value;
      owners[key] = '${area}_$locale.arb';
    }
  }

  final template = merged[templateLocale];
  if (template == null) {
    errors.add('No $templateLocale fragments found');
  } else {
    final templateKeys = template.keys.where((k) => !k.startsWith('@')).toSet();
    for (final entry in merged.entries) {
      if (entry.key == templateLocale) continue;
      final keys = entry.value.keys.where((k) => !k.startsWith('@')).toSet();
      for (final missing in templateKeys.difference(keys)) {
        errors.add('Locale ${entry.key} is missing "$missing" (defined in ${owner[templateLocale]![missing]})');
      }
      for (final extra in keys.difference(templateKeys)) {
        errors.add('Locale ${entry.key} has "$extra" which is not in $templateLocale');
      }
    }
  }

  if (errors.isNotEmpty) {
    for (final e in errors) {
      stderr.writeln('error: $e');
    }
    exit(1);
  }

  Directory(outDir).createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  for (final entry in merged.entries) {
    final out = File('$outDir/app_${entry.key}.arb');
    out.writeAsStringSync('${encoder.convert(entry.value)}\n');
    stdout.writeln('wrote ${out.path} (${entry.value.length - 1} entries)');
  }
}
