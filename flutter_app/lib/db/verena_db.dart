import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class VerenaDB {
  static Database? _db;

  static Future<Database> get instance async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final dir = await getApplicationSupportDirectory();
    final path = join(dir.path, 'verena.db');

    return openDatabase(
      path,
      version: 4,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE captures ADD COLUMN last_hash BLOB');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE captures (
            id INTEGER PRIMARY KEY,
            capture_name TEXT,
            date_created INTEGER,
            date_updated INTEGER,
            starred INTEGER DEFAULT 0,
            directory_path TEXT,
            last_hash BLOB
          );
        ''');

        await db.execute('''
         CREATE TABLE snapshots (
            id INTEGER PRIMARY KEY,
            capture_id TEXT,
            file_path TEXT,
            timestamp INTEGER,
            frame_hash BLOB,
            prev_hash BLOB,
            capture_interval TEXT,
            hidden INTEGER DEFAULT 1,
            capture_app TEXT
          );
        ''');
      },
    );
  }
}
