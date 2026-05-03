import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String> createCaptureDirectory(String name) async {
  // Sanitize folder name

  // Get base directory
  final baseDir = await getApplicationDocumentsDirectory();

  // /documents/verena/
  final verenaDir = Directory('${baseDir.path}/Verena');
  if (!(await verenaDir.exists())) {
    await verenaDir.create(recursive: true);
  }

  // /documents/verena/<project>/
  final projectDir = Directory('${verenaDir.path}/$name');

  // Subfolders
  final capturesDir = Directory('${projectDir.path}/captures');
  final thumbnailsDir = Directory('${projectDir.path}/thumbnails');

  // Create everything safely
  await capturesDir.create(recursive: true);
  await thumbnailsDir.create(recursive: true);

  return projectDir.path;
}

Future<String> renameVerenaFolder({
  required String oldCaptureDirectory,
  required String newName,
}) async {
  final baseDir = await getApplicationDocumentsDirectory();
  final verenaDir = Directory('${baseDir.path}/verena');

  final oldDir = Directory(oldCaptureDirectory);
  final newDir = Directory('${verenaDir.path}/$newName');

  if (!await oldDir.exists()) {
    throw Exception('Old folder does not exist');
  }

  if (await newDir.exists()) {
    throw Exception('Target folder already exists: $newName');
  }

  await oldDir.rename(newDir.path);

  return newDir.path;
}

Future<void> deleteCaptureDirectory(String path) async {
  final dir = Directory(path);

  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
