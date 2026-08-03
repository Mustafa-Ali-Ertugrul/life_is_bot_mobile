import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  // Private constructor (singleton pattern)
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  // Factory for easy access
  factory DatabaseService() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'life_is_bot.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE step_logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL UNIQUE,
            steps INTEGER NOT NULL,
            source TEXT NOT NULL,
            synced INTEGER DEFAULT 0,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  Future<void> saveSteps({
    required int steps,
    required DateTime date,
    String source = 'google_fit',
  }) async {
    final db = await database;
    await db.insert(
      'step_logs',
      {
        'date': date.toIso8601String().split('T')[0],
        'steps': steps,
        'source': source,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getTodaySteps() async {
    final db = await database;
    final today = DateTime.now().toIso8601String().split('T')[0];

    final results = await db.query(
      'step_logs',
      where: 'date = ?',
      whereArgs: [today],
    );

    if (results.isEmpty) return 0;
    return results.first['steps'] as int;
  }

  Future<Map<DateTime, int>> getWeeklySteps() async {
    final db = await database;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: 6));

    final results = await db.query(
      'step_logs',
      where: 'date >= ?',
      whereArgs: [startDate.toIso8601String().split('T')[0]],
      orderBy: 'date ASC',
    );

    final stepsMap = <DateTime, int>{};
    for (final row in results) {
      final date = DateTime.parse(row['date'] as String);
      stepsMap[date] = row['steps'] as int;
    }

    return stepsMap;
  }
}
