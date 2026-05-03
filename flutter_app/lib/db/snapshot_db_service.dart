import 'verena_db.dart';

class SnapshotService {
  Future<void> createSnapshot(
    int captureID,
    String filePath,
    String hash,
    String captureInterval,
  ) async {
    final db = await VerenaDB.instance;
    int now = DateTime.now().millisecondsSinceEpoch;

    await db.insert('snapshots', {
      "capture_id": captureID,
      "file_path": filePath,
      "timestamp": now,
      "hash": hash,
      "capture_interval": captureInterval,
    });
  }

  Future<List<Map<String, dynamic>>> getSnapshotsByCaptureId(
    int captureId,
  ) async {
    final db = await VerenaDB.instance;

    return await db.query(
      'snapshots',
      where: 'capture_id = ?',
      whereArgs: [captureId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<void> updateSnapshot(int id, Map<String, dynamic> values) async {
    final db = await VerenaDB.instance;

    values['date_updated'] = DateTime.now().millisecondsSinceEpoch;
    await db.update('snapshots', values, where: 'id = ?', whereArgs: [id]);
  }
}
