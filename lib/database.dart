import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;

    if (kIsWeb) {
      // Chrome Web：
      // sqflite_common_ffi_web 會把資料存到 IndexedDB
      path = 'diary_app_web.db';
    } else {
      // Android / iOS / Windows / Linux / macOS
      final databasesPath = await getDatabasesPath();
      path = join(
        databasesPath,
        'diary_app.db',
      );
    }

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.execute('''
      CREATE TABLE diaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_diaries_date
      ON diaries(date)
    ''');

    await db.execute('''
      CREATE INDEX idx_diaries_deleted_at
      ON diaries(deleted_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_diaries_favorite
      ON diaries(is_favorite)
    ''');

    await db.execute('''
      CREATE TABLE diary_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _insertDefaultTemplates(db);
  }

  Future<void> _insertDefaultTemplates(Database db) async {
    final now = DateTime.now().toIso8601String();

    final templates = [
      {
        'name': '一般日記',
        'content': '今天發生了什麼？\n\n今天的感受？\n\n其他：',
      },
      {
        'name': '工作日記',
        'content': '今天完成：\n\n遇到問題：\n\n明天要做：\n\n備註：',
      },
      {
        'name': '學習日記',
        'content': '今天學習：\n\n學到了什麼：\n\n還不懂的地方：\n\n明天繼續：',
      },
      {
        'name': '每日反思',
        'content':
            '今天最重要的事情？\n\n'
            '今天做得最好的是？\n\n'
            '今天遇到什麼問題？\n\n'
            '明天想做什麼？',
      },
    ];

    for (final template in templates) {
      await db.insert(
        'diary_templates',
        {
          'name': template['name'],
          'content': template['content'],
          'is_default': 1,
          'created_at': now,
          'updated_at': now,
        },
      );
    }
  }
}