import 'package:sqflite/sqflite.dart';

import 'database.dart';
import 'models.dart';

class DiaryRepository {
  // ============================================================
  // 分頁設定
  // ============================================================

  static const int defaultPageSize = 50;

  // ============================================================
  // 日記：一般查詢
  // ============================================================

  /// 取得全部正常日記
  ///
  /// 舊版相容方法。
  /// 如果資料量很大，新的頁面請使用 getPage()。
  Future<List<Diary>> getAll() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 分頁取得正常日記
  ///
  /// 每次預設取得 50 筆。
  ///
  /// 第 1 頁：
  /// offset = 0
  ///
  /// 第 2 頁：
  /// offset = 50
  ///
  /// 第 3 頁：
  /// offset = 100
  Future<List<Diary>> getPage({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 取得最近日記
  ///
  /// 首頁使用。
  /// 不會把全部日記載入記憶體。
  Future<List<Diary>> getRecent({
    int limit = 10,
  }) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: 'deleted_at IS NULL',
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );

    return result.map(Diary.fromMap).toList();
  }

  // ============================================================
  // 日期查詢
  // ============================================================

  /// 取得某一天的所有日記
  Future<List<Diary>> getByDate(DateTime date) async {
    final db = await AppDatabase.instance.database;

    final start = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final end = start.add(
      const Duration(days: 1),
    );

    final result = await db.query(
      'diaries',
      where: '''
        date >= ?
        AND date < ?
        AND deleted_at IS NULL
      ''',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 取得某月份的所有日記
  ///
  /// 日曆頁面使用。
  Future<List<Diary>> getByMonth(DateTime month) async {
    final db = await AppDatabase.instance.database;

    final start = DateTime(
      month.year,
      month.month,
      1,
    );

    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final result = await db.query(
      'diaries',
      where: '''
        date >= ?
        AND date < ?
        AND deleted_at IS NULL
      ''',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  // ============================================================
  // 搜尋
  // ============================================================

  /// 舊版搜尋方法
  ///
  /// 保留給目前還沒有改成分頁的頁面使用。
  /// 新版 SearchPage 請使用 searchPage()。
  Future<List<Diary>> search(String keyword) async {
    final db = await AppDatabase.instance.database;

    final value = '%${keyword.trim()}%';

    final result = await db.query(
      'diaries',
      where: '''
        deleted_at IS NULL
        AND (
          title LIKE ?
          OR content LIKE ?
        )
      ''',
      whereArgs: [
        value,
        value,
      ],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 分頁搜尋
  ///
  /// 搜尋標題 + 內容。
  ///
  /// 每次預設 50 筆。
  Future<List<Diary>> searchPage({
    required String keyword,
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final trimmedKeyword = keyword.trim();

    // 如果沒有關鍵字，直接取得一般日記分頁。
    if (trimmedKeyword.isEmpty) {
      return getPage(
        limit: limit,
        offset: offset,
      );
    }

    final value = '%$trimmedKeyword%';

    final result = await db.query(
      'diaries',
      where: '''
        deleted_at IS NULL
        AND (
          title LIKE ?
          OR content LIKE ?
        )
      ''',
      whereArgs: [
        value,
        value,
      ],
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 舊版日期範圍搜尋
  Future<List<Diary>> searchByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: '''
        date >= ?
        AND date < ?
        AND deleted_at IS NULL
      ''',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 日期範圍分頁搜尋
  Future<List<Diary>> searchByDateRangePage({
    required DateTime start,
    required DateTime end,
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: '''
        date >= ?
        AND date < ?
        AND deleted_at IS NULL
      ''',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 關鍵字 + 日期範圍分頁搜尋
  ///
  /// SearchPage 如果之後同時支援：
  /// - 關鍵字
  /// - 開始日期
  /// - 結束日期
  ///
  /// 可以直接使用這個方法。
  Future<List<Diary>> searchPageWithDateRange({
    String keyword = '',
    DateTime? start,
    DateTime? end,
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final conditions = <String>[
      'deleted_at IS NULL',
    ];

    final args = <dynamic>[];

    final trimmedKeyword = keyword.trim();

    if (trimmedKeyword.isNotEmpty) {
      conditions.add('''
        (
          title LIKE ?
          OR content LIKE ?
        )
      ''');

      final value = '%$trimmedKeyword%';

      args.add(value);
      args.add(value);
    }

    if (start != null) {
      final startDate = DateTime(
        start.year,
        start.month,
        start.day,
      );

      conditions.add('date >= ?');
      args.add(startDate.toIso8601String());
    }

    if (end != null) {
      final endDate = DateTime(
        end.year,
        end.month,
        end.day,
      ).add(const Duration(days: 1));

      conditions.add('date < ?');
      args.add(endDate.toIso8601String());
    }

    final result = await db.query(
      'diaries',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  // ============================================================
  // 新增 / 編輯
  // ============================================================

  Future<int> insert(Diary diary) async {
    final db = await AppDatabase.instance.database;

    final map = diary.toMap();

    // SQLite AUTOINCREMENT 自動產生 id
    map.remove('id');

    return db.insert(
      'diaries',
      map,
    );
  }

  Future<void> update(Diary diary) async {
    if (diary.id == null) {
      throw ArgumentError('Diary id 不可以是 null');
    }

    final db = await AppDatabase.instance.database;

    final map = diary.toMap();

    // id 不更新
    map.remove('id');

    await db.update(
      'diaries',
      map,
      where: 'id = ?',
      whereArgs: [
        diary.id,
      ],
    );
  }

  // ============================================================
  // 回收站
  // ============================================================

  /// 軟刪除
  Future<void> delete(int id) async {
    final db = await AppDatabase.instance.database;

    final now = DateTime.now().toIso8601String();

    await db.update(
      'diaries',
      {
        'deleted_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
  }

  /// 從回收站還原
  Future<void> restore(int id) async {
    final db = await AppDatabase.instance.database;

    await db.update(
      'diaries',
      {
        'deleted_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
  }

  /// 永久刪除
  Future<void> permanentlyDelete(int id) async {
    final db = await AppDatabase.instance.database;

    await db.delete(
      'diaries',
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
  }

  /// 舊版回收桶查詢
  ///
  /// 保留相容性。
  /// 新版回收桶頁面請使用 getTrashPage()。
  Future<List<Diary>> getTrash() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 回收桶分頁
  Future<List<Diary>> getTrashPage({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: 'deleted_at IS NOT NULL',
      orderBy: 'deleted_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 清空回收桶
  Future<void> emptyTrash() async {
    final db = await AppDatabase.instance.database;

    await db.delete(
      'diaries',
      where: 'deleted_at IS NOT NULL',
    );
  }

  // ============================================================
  // 備份專用：取得全部資料
  // 包含正常日記 + 回收站
  //
  // 注意：
  // 備份不能使用分頁。
  // 因為備份就是要取得完整資料。
  // ============================================================

  Future<List<Diary>> getAllForBackup() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  // ============================================================
  // 收藏
  // ============================================================

  Future<void> toggleFavorite(
    int id,
    bool favorite,
  ) async {
    final db = await AppDatabase.instance.database;

    await db.update(
      'diaries',
      {
        'is_favorite': favorite ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
  }

  /// 舊版收藏查詢
  ///
  /// 保留相容性。
  /// 新版收藏頁面請使用 getFavoritesPage()。
  Future<List<Diary>> getFavorites() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: '''
        deleted_at IS NULL
        AND is_favorite = 1
      ''',
      orderBy: 'date DESC, id DESC',
    );

    return result.map(Diary.fromMap).toList();
  }

  /// 收藏分頁
  Future<List<Diary>> getFavoritesPage({
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diaries',
      where: '''
        deleted_at IS NULL
        AND is_favorite = 1
      ''',
      orderBy: 'date DESC, id DESC',
      limit: limit,
      offset: offset,
    );

    return result.map(Diary.fromMap).toList();
  }

  // ============================================================
  // 統計
  // ============================================================

  Future<int> getTotalCount() async {
    final db = await AppDatabase.instance.database;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS count
      FROM diaries
      WHERE deleted_at IS NULL
    ''');

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getYearCount(int year) async {
    final db = await AppDatabase.instance.database;

    final start = DateTime(
      year,
      1,
      1,
    );

    final end = DateTime(
      year + 1,
      1,
      1,
    );

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM diaries
      WHERE date >= ?
      AND date < ?
      AND deleted_at IS NULL
      ''',
      [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  Future<int> getMonthCount(
    int year,
    int month,
  ) async {
    final db = await AppDatabase.instance.database;

    final start = DateTime(
      year,
      month,
      1,
    );

    final end = DateTime(
      year,
      month + 1,
      1,
    );

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM diaries
      WHERE date >= ?
      AND date < ?
      AND deleted_at IS NULL
      ''',
      [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    return (result.first['count'] as int?) ?? 0;
  }

  // ============================================================
  // 模板
  // ============================================================

  Future<List<DiaryTemplate>> getTemplates() async {
    final db = await AppDatabase.instance.database;

    final result = await db.query(
      'diary_templates',
      orderBy: 'is_default DESC, name ASC',
    );

    return result
        .map(DiaryTemplate.fromMap)
        .toList();
  }

  Future<int> insertTemplate(
    DiaryTemplate template,
  ) async {
    final db = await AppDatabase.instance.database;

    final map = template.toMap();

    map.remove('id');

    return db.insert(
      'diary_templates',
      map,
    );
  }

  Future<void> updateTemplate(
    DiaryTemplate template,
  ) async {
    if (template.id == null) {
      throw ArgumentError(
        'Template id 不可以是 null',
      );
    }

    final db = await AppDatabase.instance.database;

    final map = template.toMap();

    map.remove('id');

    await db.update(
      'diary_templates',
      map,
      where: 'id = ?',
      whereArgs: [
        template.id,
      ],
    );
  }

  Future<void> deleteTemplate(int id) async {
    final db = await AppDatabase.instance.database;

    await db.delete(
      'diary_templates',
      where: 'id = ?',
      whereArgs: [
        id,
      ],
    );
  }

  // ============================================================
  // 備份還原
  // ============================================================

  Future<void> importBackup({
    required List<Diary> diaries,
    required List<DiaryTemplate> templates,
  }) async {
    final db = await AppDatabase.instance.database;

    await db.transaction(
      (txn) async {
        // --------------------------------------------------------
        // 匯入前清空現有資料
        // --------------------------------------------------------

        await txn.delete('diaries');
        await txn.delete('diary_templates');

        // --------------------------------------------------------
        // 還原日記
        // --------------------------------------------------------

        for (final diary in diaries) {
          final map = diary.toMap();

          await txn.insert(
            'diaries',
            map,
            conflictAlgorithm:
                ConflictAlgorithm.replace,
          );
        }

        // --------------------------------------------------------
        // 還原模板
        // --------------------------------------------------------

        for (final template in templates) {
          final map = template.toMap();

          await txn.insert(
            'diary_templates',
            map,
            conflictAlgorithm:
                ConflictAlgorithm.replace,
          );
        }
      },
    );
  }
}