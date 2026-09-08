import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class ScheduleStore {
  ScheduleStore({Database? database}) : _database = database;

  Database? _database;

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final dbPath = path.join(await getDatabasesPath(), 're_schedule.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            teacher TEXT NOT NULL,
            location TEXT NOT NULL,
            day_of_week INTEGER NOT NULL,
            start_period INTEGER NOT NULL,
            end_period INTEGER NOT NULL,
            weeks TEXT NOT NULL,
            color_index INTEGER NOT NULL,
            notes TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE semester_settings (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            name TEXT NOT NULL,
            start_date TEXT,
            total_weeks INTEGER,
            period_times TEXT NOT NULL,
            theme TEXT NOT NULL
          )
        ''');
      },
    );
    return _database!;
  }

  Future<List<Course>> loadCourses() async {
    final db = await _db;
    final rows = await db.query(
      'courses',
      orderBy: 'day_of_week, start_period, name',
    );
    return rows.map(Course.fromMap).toList(growable: false);
  }

  Future<SemesterSettings> loadSettings() async {
    final db = await _db;
    final rows = await db.query('semester_settings', limit: 1);
    return rows.isEmpty
        ? const SemesterSettings()
        : SemesterSettings.fromMap(rows.first);
  }

  Future<void> saveSettings(SemesterSettings settings) async {
    final db = await _db;
    await db.insert(
      'semester_settings',
      settings.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveCourse(Course course) async {
    final db = await _db;
    await db.insert(
      'courses',
      course.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteCourse(String id) async {
    final db = await _db;
    await db.delete('courses', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceCourses(List<Course> courses) async {
    final db = await _db;
    await db.transaction((transaction) async {
      await transaction.delete('courses');
      final batch = transaction.batch();
      for (final course in courses) {
        batch.insert('courses', course.toMap());
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> clearCourses() => replaceCourses(const []);

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
