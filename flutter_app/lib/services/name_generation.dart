import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> generateUniqueProjectName(String name) async {
  final baseDir = await getApplicationDocumentsDirectory();
  final verenaDir = Directory('${baseDir.path}/Verena');

  if (!await verenaDir.exists()) {
    return name;
  }

  String sanitizeName(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[\/\\:*?"<>|]'), '_') // invalid filesystem chars
        .replaceAll(RegExp(r'\s+'), ' ') // normalize whitespace
        .replaceAll(RegExp(r'_+'), '_'); // collapse underscores
  }

  name = sanitizeName(name);

  final existing = verenaDir
      .listSync()
      .whereType<Directory>()
      .map((d) => d.path.split(Platform.pathSeparator).last)
      .toList();
  final baseName = name.trim();
  if (!existing.contains(baseName)) {
    return baseName;
  }
  int maxSuffix = 0;

  final regex = RegExp(r'^' + RegExp.escape(baseName) + r'(?: \((\d+)\))?$');

  for (final folder in existing) {
    final match = regex.firstMatch(folder);
    if (match != null) {
      final numGroup = match.group(1);
      if (numGroup != null) {
        final n = int.tryParse(numGroup) ?? 0;
        if (n > maxSuffix) {
          maxSuffix = n;
        }
      } else {
        // plain "Project" counts as 0 baseline
        if (maxSuffix == 0) {
          maxSuffix = 0;
        }
      }
    }
  }

  return '$baseName (${maxSuffix + 1})';
}
