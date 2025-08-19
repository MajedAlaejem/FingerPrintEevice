import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fingerprints.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE fingerprints(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            template TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> insertFingerprint(String name, String template) async {
    final db = await database;
    return db.insert('fingerprints', {'name': name, 'template': template});
  }

  static Future<List<Map<String, dynamic>>> getFingerprints() async {
    final db = await database;
    return db.query('fingerprints', orderBy: 'id DESC');
  }

  static Future<int> deleteFingerprint(int id) async {
    final db = await database;
    return db.delete('fingerprints', where: 'id = ?', whereArgs: [id]);
  }
}
