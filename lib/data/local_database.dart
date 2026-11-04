import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/student.dart';

class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();
  Database? _db;
  final _uuid = const Uuid();

  Future<Database> get database async {
    if (_db != null) return _db!;
    final root = await getDatabasesPath();
    _db = await openDatabase(
      p.join(root, 'daftar_taqyim.db'), version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE students (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, birth_date TEXT NOT NULL DEFAULT '',
          gender TEXT NOT NULL DEFAULT 'غير محدد', class_name TEXT NOT NULL DEFAULT 'القسم التحضيري',
          national_id TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
          evaluations_json TEXT NOT NULL DEFAULT '{}', history_json TEXT NOT NULL DEFAULT '[]',
          legacy_json TEXT NOT NULL DEFAULT '{}', created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        )''');
        await db.execute('CREATE INDEX students_name_idx ON students(name)');
        await db.execute('CREATE INDEX students_class_idx ON students(class_name)');
        await db.execute('''CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
      },
    );
    return _db!;
  }

  Future<List<Student>> getStudents({String query = '', String className = ''}) async {
    final db = await database;
    final where = <String>[]; final args = <Object>[];
    if (query.trim().isNotEmpty) { where.add('(name LIKE ? OR national_id LIKE ?)'); args..add('%${query.trim()}%')..add('%${query.trim()}%'); }
    if (className.isNotEmpty) { where.add('class_name = ?'); args.add(className); }
    final rows = await db.query('students', where: where.isEmpty ? null : where.join(' AND '), whereArgs: args, orderBy: 'name COLLATE NOCASE');
    return rows.map(Student.fromMap).toList();
  }

  Future<Student?> getStudent(String id) async {
    final rows = await (await database).query('students', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Student.fromMap(rows.first);
  }

  Future<void> saveStudent(Student student) async {
    final db = await database;
    await db.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteStudent(String id) async => (await database).delete('students', where: 'id = ?', whereArgs: [id]);

  Future<int> countStudents() async => Sqflite.firstIntValue(await (await database).rawQuery('SELECT COUNT(*) FROM students')) ?? 0;
  Future<List<String>> getClasses() async {
    final rows = await (await database).rawQuery("SELECT DISTINCT class_name FROM students WHERE class_name <> '' ORDER BY class_name");
    return rows.map((e) => '${e['class_name']}').toList();
  }

  /// Imports both legacy students_data.json (name-keyed map) and this app's backup.
  /// Unknown fields and each original record are retained in legacy_json.
  Future<Map<String, int>> importJson(String source) async {
    final decoded = jsonDecode(source);
    final Map<String, dynamic> records;
    if (decoded is Map && decoded['format'] == 'daftar_taqyim_backup' && decoded['students'] is List) {
      records = {for (final item in decoded['students']) '${item['name']}': item as Map<String, dynamic>};
    } else if (decoded is Map) {
      records = decoded.map((k, v) => MapEntry('$k', v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{}));
    } else if (decoded is List) {
      records = {for (final item in decoded) '${item['name'] ?? item['fullName'] ?? ''}': Map<String, dynamic>.from(item as Map)};
    } else { throw const FormatException('صيغة الملف غير مدعومة'); }

    var added = 0, updated = 0, skipped = 0;
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in records.entries) {
        final name = entry.key.trim(); if (name.isEmpty) { skipped++; continue; }
        final raw = entry.value;
        final isNewBackup = raw.containsKey('id') && raw.containsKey('evaluations');
        final info = raw['info'] is Map ? Map<String, dynamic>.from(raw['info']) : raw;
        final oldRows = await txn.query('students', where: 'name = ?', whereArgs: [name], limit: 1);
        final old = oldRows.isEmpty ? null : Student.fromMap(oldRows.first);
        final rawEvaluations = raw['evaluations'] is Map ? Map<String, dynamic>.from(raw['evaluations']) : <String, dynamic>{};
        final rawHistory = raw['assessment_history'] ?? raw['history'] ?? [];
        final student = Student(
          id: old?.id ?? (isNewBackup ? '${raw['id']}' : _uuid.v4()), name: name,
          birthDate: '${info['dob'] ?? info['birthDate'] ?? info['birth_date'] ?? old?.birthDate ?? ''}',
          gender: '${info['gender'] ?? old?.gender ?? 'غير محدد'}',
          className: '${info['class_level'] ?? info['className'] ?? info['class_name'] ?? old?.className ?? 'القسم التحضيري'}',
          nationalId: '${info['id'] ?? info['nationalId'] ?? info['matricule'] ?? old?.nationalId ?? ''}',
          notes: '${info['notes'] ?? old?.notes ?? ''}',
          evaluations: rawEvaluations.isNotEmpty ? rawEvaluations : (old?.evaluations ?? {}),
          history: rawHistory is List && rawHistory.isNotEmpty ? rawHistory : (old?.history ?? []),
          legacy: {...?old?.legacy, 'source_record': raw, 'source_format': isNewBackup ? 'app_backup' : 'legacy_students_data'},
          createdAt: old?.createdAt ?? DateTime.now().toIso8601String(), updatedAt: DateTime.now().toIso8601String(),
        );
        await txn.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        if (old == null) { added++; } else { updated++; }
      }
    });
    return {'added': added, 'updated': updated, 'skipped': skipped};
  }

  Future<String> exportJson() async {
    final students = await getStudents();
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'daftar_taqyim_backup', 'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'students': students.map((s) => {
        'id': s.id, 'name': s.name, 'info': {
          'dob': s.birthDate, 'gender': s.gender, 'class_level': s.className,
          'id': s.nationalId, 'notes': s.notes,
        },
        'evaluations': s.evaluations, 'assessment_history': s.history,
        'legacy': s.legacy,
      }).toList(),
    });
  }

  Future<void> clearAll() async => (await database).delete('students');
  String newId() => _uuid.v4();
}
