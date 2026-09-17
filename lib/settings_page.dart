
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'diary_edit_page.dart';
import 'models.dart';
import 'providers.dart';
import 'repository.dart';
import 'statistics_page.dart';
import 'template_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _backupJson(BuildContext context) async {
    try {
      final repository = DiaryRepository();

      final diaries = await repository.getAllForBackup();
      final templates = await repository.getTemplates();

      final data = {
        'format': 'diary_app_backup',
        'version': 1,
        'exported_at': DateTime.now().toIso8601String(),
        'diaries': diaries.map((e) => e.toMap()).toList(),
        'templates': templates.map((e) => e.toMap()).toList(),
      };

      final jsonText =
          const JsonEncoder.withIndent('  ').convert(data);

      final bytes =
          Uint8List.fromList(utf8.encode(jsonText));

      await FileSaver.instance.saveFile(
        name:
            'diary_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('備份完成'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('備份失敗：$e'),
          ),
        );
      }
    }
  }

  Future<void> _restoreJson(BuildContext context) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty) return;

      final file = result.single;

      final bytes = await file.readAsBytes();

      final jsonText = utf8.decode(bytes);

      final dynamic decoded =
          jsonDecode(jsonText);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('JSON 格式錯誤');
      }

      if (decoded['format'] != 'diary_app_backup') {
        throw Exception('這不是日記 App 的完整備份檔');
      }

      if (decoded['version'] != 1) {
        throw Exception('不支援的備份版本');
      }

      final diariesJson = decoded['diaries'];

      final templatesJson = decoded['templates'];

      if (diariesJson is! List ||
          templatesJson is! List) {
        throw Exception('備份資料不完整');
      }

      final diaries = diariesJson
          .map(
            (e) => Diary.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();

      final templates = templatesJson
          .map(
            (e) => DiaryTemplate.fromMap(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList();

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('還原資料'),
            content: Text(
              '還原會刪除目前所有日記與模板，'
              '再使用備份檔覆蓋。\n\n'
              '日記：${diaries.length} 篇\n'
              '模板：${templates.length} 個\n\n'
              '確定要繼續嗎？',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('確定還原'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      await DiaryRepository().importBackup(
        diaries: diaries,
        templates: templates,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('還原完成，重新整理後即可看到資料'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('還原失敗：$e'),
          ),
        );
      }
    }
  }

  Future<void> _importSingleDiary(
    BuildContext context,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result.isEmpty) return;

      final file = result.single;

      final bytes = await file.readAsBytes();

      final jsonText = utf8.decode(bytes);

      final dynamic decoded =
          jsonDecode(jsonText);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('JSON 格式錯誤');
      }

      if (decoded['format'] != 'diary_app_entry') {
        throw Exception('這不是單篇日記匯出檔');
      }

      if (decoded['version'] != 1) {
        throw Exception('不支援的單篇日記版本');
      }

      final diaryJson = decoded['diary'];

      if (diaryJson is! Map) {
        throw Exception('單篇日記資料格式錯誤');
      }

      final source =
          Map<String, dynamic>.from(diaryJson);

      final date = DateTime.parse(
        source['date'] as String,
      );

      final title =
          source['title'] as String? ?? '';

      final content =
          source['content'] as String? ?? '';

      final isFavorite =
          source['is_favorite'] == 1 ||
          source['is_favorite'] == true;

      final createdAt = DateTime.parse(
        source['created_at'] as String,
      );

      final updatedAt = DateTime.parse(
        source['updated_at'] as String,
      );

      final diary = Diary(
        id: null,
        date: date,
        title: title,
        content: content,
        isFavorite: isFavorite,
        createdAt: createdAt,
        updatedAt: updatedAt,
        deletedAt: null,
      );

      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('匯入單篇日記'),
            content: Text(
              '確定要匯入這篇日記嗎？\n\n'
              '日期：${DateFormat('yyyy/MM/dd').format(date)}\n'
              '標題：${title.isEmpty ? '無標題' : title}\n\n'
              '匯入後會建立一篇新的日記。',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('匯入'),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;

      await DiaryRepository().insert(diary);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('單篇日記匯入完成'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('匯入失敗：$e'),
          ),
        );
      }
    }
  }

  Future<void> _exportMarkdown(
    BuildContext context,
  ) async {
    try {
      final diaries =
          await DiaryRepository().getAll();

      final buffer = StringBuffer();

      buffer.writeln('# 我的日記');
      buffer.writeln();

      String? currentMonth;

      for (final diary in diaries) {
        final month =
            DateFormat('yyyy.MM').format(diary.date);

        if (currentMonth != month) {
          currentMonth = month;

          buffer.writeln();
          buffer.writeln('## $month');
          buffer.writeln();
        }

        buffer.writeln(
          '### ${DateFormat('yyyy/MM/dd').format(diary.date)} '
          '${diary.title.isEmpty ? '無標題' : diary.title}',
        );

        buffer.writeln();

        buffer.writeln(diary.content);

        buffer.writeln();

        if (diary.isFavorite) {
          buffer.writeln('⭐ 收藏');
          buffer.writeln();
        }

        buffer.writeln('---');
        buffer.writeln();
      }

      final bytes = Uint8List.fromList(
        utf8.encode(buffer.toString()),
      );

      await FileSaver.instance.saveFile(
        name:
            'diary_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}',
        bytes: bytes,
        fileExtension: 'md',
        mimeType: MimeType.text,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Markdown 匯出完成'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Markdown 匯出失敗：$e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
      ),
      body: ListView(
        children: [
          const _SectionTitle(
            title: '日記管理',
          ),

          ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('我的收藏'),
            subtitle: const Text('查看所有收藏的日記'),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FavoritePage(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.delete_outline,
            ),
            title: const Text('回收站'),
            subtitle: const Text('查看與還原已刪除的日記'),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrashPage(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.description_outlined,
            ),
            title: const Text('日記模板'),
            subtitle: const Text('管理與建立日記模板'),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TemplatePage(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(
              Icons.bar_chart_outlined,
            ),
            title: const Text('統計'),
            subtitle: const Text('查看日記統計資料'),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StatisticsPage(),
                ),
              );
            },
          ),

          const Divider(),

          const _SectionTitle(
            title: '資料管理',
          ),

          ListTile(
            leading: const Icon(
              Icons.download_outlined,
            ),
            title: const Text('備份全部資料'),
            subtitle: const Text(
              '將所有日記與模板備份成 JSON',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => _backupJson(context),
          ),

          ListTile(
            leading: const Icon(
              Icons.upload_outlined,
            ),
            title: const Text('還原全部資料'),
            subtitle: const Text(
              '從 JSON 備份檔完整還原',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => _restoreJson(context),
          ),

          ListTile(
            leading: const Icon(
              Icons.note_add_outlined,
            ),
            title: const Text('匯入單篇日記'),
            subtitle: const Text(
              '從單篇 JSON 日記檔匯入',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => _importSingleDiary(context),
          ),

          ListTile(
            leading: const Icon(
              Icons.article_outlined,
            ),
            title: const Text('匯出 Markdown'),
            subtitle: const Text(
              '將所有日記匯出成 Markdown',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => _exportMarkdown(context),
          ),

          const Divider(),

          const _SectionTitle(
            title: '關於',
          ),

          const ListTile(
            leading: Icon(
              Icons.book_outlined,
            ),
            title: Text('我的日記'),
            subtitle: Text('版本 1.0.0'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        20,
        16,
        8,
      ),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context)
                  .colorScheme
                  .primary,
            ),
      ),
    );
  }
}

class FavoritePage extends ConsumerStatefulWidget {
  const FavoritePage({super.key});

  @override
  ConsumerState<FavoritePage> createState() =>
      _FavoritePageState();
}

class _FavoritePageState
    extends ConsumerState<FavoritePage> {
  static const int _pageSize = 50;

  final ScrollController _scrollController =
      ScrollController();

  final List<Diary> _items = [];

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _onScroll,
    );

    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
        .removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent -
            300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
      _items.clear();
    });

    try {
      final result = await ref
          .read(diaryRepositoryProvider)
          .getFavoritesPage(
            limit: _pageSize,
            offset: 0,
          );

      if (!mounted) return;

      setState(() {
        _items.addAll(result);
        _offset = result.length;
        _hasMore =
            result.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await ref
          .read(diaryRepositoryProvider)
          .getFavoritesPage(
            limit: _pageSize,
            offset: _offset,
          );

      if (!mounted) return;

      setState(() {
        _items.addAll(result);
        _offset += result.length;
        _hasMore =
            result.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _editDiary(Diary diary) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryEditPage(
          diary: diary,
        ),
      ),
    );

    await _loadInitial();
  }

  Future<void> _removeFavorite(
    Diary diary,
  ) async {
    if (diary.id == null) return;

    await ref
        .read(diaryRepositoryProvider)
        .toggleFavorite(
          diary.id!,
          false,
        );

    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的收藏'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _items.isEmpty && _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text('目前沒有收藏的日記'),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _items.length +
                            (_loading || _hasMore
                                ? 1
                                : 0),
                    itemBuilder:
                        (context, index) {
                      if (index >=
                          _items.length) {
                        return const Padding(
                          padding:
                              EdgeInsets.all(20),
                          child: Center(
                            child:
                                CircularProgressIndicator(),
                          ),
                        );
                      }

                      final diary =
                          _items[index];

                      return ListTile(
                        leading: const Icon(
                          Icons.star,
                        ),
                        title: Text(
                          diary.title.isEmpty
                              ? '無標題'
                              : diary.title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy/MM/dd').format(diary.date)}\n'
                          '${diary.content}',
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing:
                            PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editDiary(diary);
                            } else if (
                                value ==
                                    'remove') {
                              _removeFavorite(
                                diary,
                              );
                            }
                          },
                          itemBuilder:
                              (context) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('編輯'),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child:
                                  Text('取消收藏'),
                            ),
                          ],
                        ),
                        onTap: () =>
                            _editDiary(diary),
                      );
                    },
                  ),
      ),
    );
  }
}

class TrashPage extends ConsumerStatefulWidget {
  const TrashPage({super.key});

  @override
  ConsumerState<TrashPage> createState() =>
      _TrashPageState();
}

class _TrashPageState
    extends ConsumerState<TrashPage> {
  static const int _pageSize = 50;

  final ScrollController _scrollController =
      ScrollController();

  final List<Diary> _items = [];

  int _offset = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _onScroll,
    );

    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
        .removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent -
            300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
      _items.clear();
    });

    try {
      final result = await ref
          .read(diaryRepositoryProvider)
          .getTrashPage(
            limit: _pageSize,
            offset: 0,
          );

      if (!mounted) return;

      setState(() {
        _items.addAll(result);
        _offset = result.length;
        _hasMore =
            result.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      final result = await ref
          .read(diaryRepositoryProvider)
          .getTrashPage(
            limit: _pageSize,
            offset: _offset,
          );

      if (!mounted) return;

      setState(() {
        _items.addAll(result);
        _offset += result.length;
        _hasMore =
            result.length == _pageSize;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _restoreDiary(
    Diary diary,
  ) async {
    if (diary.id == null) return;

    await ref
        .read(diaryRepositoryProvider)
        .restore(diary.id!);

    ref.invalidate(diaryListProvider);
    ref.invalidate(recentDiaryProvider);

    await _loadInitial();
  }

  Future<void> _permanentlyDelete(
    Diary diary,
  ) async {
    if (diary.id == null) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('永久刪除'),
          content: const Text(
            '確定要永久刪除這篇日記嗎？\n'
            '刪除後無法恢復。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('永久刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref
        .read(diaryRepositoryProvider)
        .permanentlyDelete(
          diary.id!,
        );

    await _loadInitial();
  }

  Future<void> _emptyTrash() async {
    if (_items.isEmpty) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('清空回收站'),
          content: const Text(
            '確定要永久刪除回收站中的所有日記嗎？\n'
            '此操作無法恢復。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('清空'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref
        .read(diaryRepositoryProvider)
        .emptyTrash();

    await _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回收站'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: '清空回收站',
              onPressed: _emptyTrash,
              icon: const Icon(
                Icons.delete_forever_outlined,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _items.isEmpty && _loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _items.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(
                        child: Text('回收站是空的'),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount:
                        _items.length +
                            (_loading || _hasMore
                                ? 1
                                : 0),
                    itemBuilder:
                        (context, index) {
                      if (index >=
                          _items.length) {
                        return const Padding(
                          padding:
                              EdgeInsets.all(20),
                          child: Center(
                            child:
                                CircularProgressIndicator(),
                          ),
                        );
                      }

                      final diary =
                          _items[index];

                      return ListTile(
                        leading: const Icon(
                          Icons.delete_outline,
                        ),
                        title: Text(
                          diary.title.isEmpty
                              ? '無標題'
                              : diary.title,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy/MM/dd').format(diary.date)}\n'
                          '${diary.content}',
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing:
                            PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value ==
                                'restore') {
                              _restoreDiary(
                                diary,
                              );
                            } else if (
                                value ==
                                    'delete') {
                              _permanentlyDelete(
                                diary,
                              );
                            }
                          },
                          itemBuilder:
                              (context) => const [
                            PopupMenuItem(
                              value: 'restore',
                              child:
                                  Text('還原'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child:
                                  Text('永久刪除'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

