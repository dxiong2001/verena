import 'verena_db.dart';
import 'capture.dart';
import 'dart:io';
import 'dart:typed_data';

class CaptureDBService {
  Future<int> createCapture(
    String name,
    String directory,
    Uint8List hash,
  ) async {
    final db = await VerenaDB.instance;
    int now = DateTime.now().millisecondsSinceEpoch;

    return await db.insert('captures', {
      'capture_name': name,
      'date_created': now,
      'date_updated': now,
      'directory_path': directory,
      'last_hash': hash,
    });
  }

  Future<List<Capture>> getAllCaptures() async {
    final db = await VerenaDB.instance;
    // await db.delete('captures');
    // await db.delete('snapshots');
    print("test");
    final result = await db.query('captures', orderBy: 'date_created DESC');

    return result.map((map) => Capture.fromMap(map)).toList();
  }

  Future<Capture?> getCaptureById(int id) async {
    final db = await VerenaDB.instance;
    // await db.delete('captures');
    final result = await db.query(
      'captures',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isNotEmpty) {
      return Capture.fromMap(result.first);
    }

    return null;
  }

  Future<void> updateCapture(int id, Capture newCapture) async {
    final db = await VerenaDB.instance;
    Map<String, dynamic> values = newCapture.toMap();
    values['date_updated'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('captures', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCaptureById(int id) async {
    final db = await VerenaDB.instance;

    await db.transaction((txn) async {
      final snapshots = await txn.query(
        'snapshots',
        where: 'capture_id = ?',
        whereArgs: [id],
      );

      for (final snap in snapshots) {
        final path = snap['file_path'] as String;
        final file = File(path);

        if (await file.exists()) {
          await file.delete();
        }
      }

      await txn.delete('snapshots', where: 'capture_id = ?', whereArgs: [id]);

      await txn.delete('captures', where: 'id = ?', whereArgs: [id]);
    });
  }
}
