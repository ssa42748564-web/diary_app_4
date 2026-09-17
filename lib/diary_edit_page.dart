
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'providers.dart';
import 'template_page.dart';

class DiaryEditPage extends ConsumerStatefulWidget {
  final Diary? diary;
  final String? initialContent;

  const DiaryEditPage({
    super.key,
    this.diary,
    this.initialContent,
  });

  @override
  ConsumerState<DiaryEditPage> createState() =>
      _DiaryEditPageState();
}

class _DiaryEditPageState
    extends ConsumerState<DiaryEditPage> {
  late DateTime _date;

  late TextEditingController _titleController;
  late TextEditingController _contentController;

  bool _isFavorite = false;

  bool _saving = false;
  bool _exportingJson = false;
  bool _exportingMarkdown = false;

  bool get _isEditing => widget.diary != null;

  @override
  void initState() {
    super.initState();

    final diary = widget.diary;

    _date = diary?.date ?? DateTime.now();

    _titleController = TextEditingController(
      text: diary?.title ?? '',
    );

    _contentController = TextEditingController(
      text: diary?.content ??
          widget.initialContent ??
          '',
    );

    _isFavorite =
        diary?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();

    super.dispose();
  }

  // ============================================================
  // 選擇日期
  // ============================================================

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );

    if (selected == null) return;

    setState(() {
      _date = selected;
    });
  }

  // ============================================================
  // 選擇模板
  // ============================================================

  Future<void> _selectTemplate() async {
    final content =
        await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const TemplatePage(
          selectMode: true,
        ),
      ),
    );

    if (content == null) return;

    setState(() {
      if (_contentController.text
          .trim()
          .isEmpty) {
        _contentController.text =
            content;
      } else {
        _contentController.text =
            '${_contentController.text}\n\n$content';
      }
    });
  }

  // ============================================================
  // 建立目前日記資料
  // ============================================================

  Diary _buildCurrentDiary() {
    final now = DateTime.now();

    return Diary(
      id: widget.diary?.id,
      date: _date,
      title: _titleController.text.trim(),
      content: _contentController.text,
      isFavorite: _isFavorite,
      createdAt:
          widget.diary?.createdAt ?? now,
      updatedAt: now,
      deletedAt: null,
    );
  }

  // ============================================================
  // 儲存
  // ============================================================

  Future<void> _save() async {
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      final repository =
          ref.read(diaryRepositoryProvider);

      final diary =
          _buildCurrentDiary();

      if (_isEditing) {
        await repository.update(diary);
      } else {
        await repository.insert(diary);
      }

      ref.invalidate(diaryListProvider);
      ref.invalidate(recentDiaryProvider);
      ref.invalidate(templateListProvider);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              '儲存失敗：$e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  // ============================================================
  // 單篇 JSON 匯出
  //
  // 注意：
  // 不匯出 id
  // 匯入時會建立新的 SQLite id
  // ============================================================

  Future<void> _exportSingleJson() async {
    if (!_isEditing ||
        widget.diary == null) {
      return;
    }

    if (_exportingJson ||
        _exportingMarkdown) {
      return;
    }

    setState(() {
      _exportingJson = true;
    });

    try {
      final diary = widget.diary!;

      final data = {
        'format': 'diary_app_entry',
        'version': 1,
        'exported_at':
            DateTime.now()
                .toIso8601String(),
        'diary': {
          'date':
              diary.date.toIso8601String(),
          'title': diary.title,
          'content': diary.content,
          'is_favorite':
              diary.isFavorite ? 1 : 0,
          'created_at':
              diary.createdAt
                  .toIso8601String(),
          'updated_at':
              diary.updatedAt
                  .toIso8601String(),
        },
      };

      final jsonText =
          const JsonEncoder
              .withIndent('  ')
              .convert(data);

      final bytes =
          Uint8List.fromList(
        utf8.encode(jsonText),
      );

      final cleanTitle =
          _safeFileName(
        diary.title,
      );

      await FileSaver.instance.saveFile(
        name:
            'diary_${DateFormat('yyyyMMdd').format(diary.date)}_$cleanTitle',
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '單篇 JSON 匯出完成',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'JSON 匯出失敗：$e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingJson = false;
        });
      }
    }
  }

  // ============================================================
  // 單篇 Markdown 匯出
  // ============================================================

  Future<void> _exportSingleMarkdown() async {
    if (!_isEditing ||
        widget.diary == null) {
      return;
    }

    if (_exportingJson ||
        _exportingMarkdown) {
      return;
    }

    setState(() {
      _exportingMarkdown = true;
    });

    try {
      final diary = widget.diary!;

      final buffer = StringBuffer();

      // 標題
      buffer.writeln(
        '# ${diary.title.trim().isEmpty ? '無標題' : diary.title.trim()}',
      );

      buffer.writeln();

      // 日期
      buffer.writeln(
        '**日期：** ${DateFormat('yyyy/MM/dd').format(diary.date)}',
      );

      buffer.writeln();

      // 收藏
      if (diary.isFavorite) {
        buffer.writeln(
          '**收藏：** ⭐',
        );

        buffer.writeln();
      }

      buffer.writeln('---');

      buffer.writeln();

      // 內容
      buffer.writeln(
        diary.content,
      );

      buffer.writeln();

      // 建立時間
      buffer.writeln('---');

      buffer.writeln();

      buffer.writeln(
        '**建立時間：** '
        '${DateFormat('yyyy/MM/dd HH:mm').format(diary.createdAt)}',
      );

      buffer.writeln();

      buffer.writeln(
        '**最後修改：** '
        '${DateFormat('yyyy/MM/dd HH:mm').format(diary.updatedAt)}',
      );

      buffer.writeln();

      final markdown =
          buffer.toString();

      final bytes =
          Uint8List.fromList(
        utf8.encode(markdown),
      );

      final cleanTitle =
          _safeFileName(
        diary.title,
      );

      await FileSaver.instance.saveFile(
        name:
            'diary_${DateFormat('yyyyMMdd').format(diary.date)}_$cleanTitle',
        bytes: bytes,
        fileExtension: 'md',
        mimeType: MimeType.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '單篇 Markdown 匯出完成',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Markdown 匯出失敗：$e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingMarkdown = false;
        });
      }
    }
  }

  // ============================================================
  // 檔名清理
  // ============================================================

  String _safeFileName(String title) {
    final safeTitle =
        title.trim().isEmpty
            ? '無標題'
            : title.trim();

    return safeTitle
        .replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        )
        .replaceAll(
          RegExp(r'\s+'),
          '_',
        );
  }

  // ============================================================
  // 匯出選單
  // ============================================================

  Future<void> _showExportMenu() async {
    if (!_isEditing ||
        widget.diary == null) {
      return;
    }

    if (_exportingJson ||
        _exportingMarkdown) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  8,
                ),
                child: Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    '匯出這篇日記',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // JSON
              ListTile(
                leading: const Icon(
                  Icons.data_object,
                ),
                title: const Text(
                  '匯出 JSON',
                ),
                subtitle: const Text(
                  '可重新匯入到日記 App',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportSingleJson();
                },
              ),

              // Markdown
              ListTile(
                leading: const Icon(
                  Icons.article_outlined,
                ),
                title: const Text(
                  '匯出 Markdown',
                ),
                subtitle: const Text(
                  '適合 Obsidian、VS Code 等工具',
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _exportSingleMarkdown();
                },
              ),

              const SizedBox(
                height: 12,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // 刪除
  // ============================================================

  Future<void> _delete() async {
    if (widget.diary?.id == null) {
      return;
    }

    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '刪除日記',
          ),
          content: const Text(
            '確定要刪除這篇日記嗎？\n'
            '日記會先移到回收站。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text(
                '取消',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                '刪除',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return;
    }

    try {
      await ref
          .read(diaryRepositoryProvider)
          .delete(
            widget.diary!.id!,
          );

      ref.invalidate(
        diaryListProvider,
      );

      ref.invalidate(
        recentDiaryProvider,
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              '刪除失敗：$e',
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final exporting =
        _exportingJson ||
        _exportingMarkdown;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? '編輯日記'
              : '新增日記',
        ),
        actions: [
          // 模板
          IconButton(
            tooltip: '模板',
            onPressed:
                _selectTemplate,
            icon: const Icon(
              Icons.description_outlined,
            ),
          ),

          // 收藏
          IconButton(
            tooltip: '收藏',
            onPressed: () {
              setState(() {
                _isFavorite =
                    !_isFavorite;
              });
            },
            icon: Icon(
              _isFavorite
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),

          // 單篇匯出
          if (_isEditing)
            IconButton(
              tooltip: '匯出',
              onPressed:
                  exporting
                      ? null
                      : _showExportMenu,
              icon: exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.download_outlined,
                    ),
            ),

          // 刪除
          if (_isEditing)
            IconButton(
              tooltip: '刪除',
              onPressed:
                  _delete,
              icon: const Icon(
                Icons.delete_outline,
              ),
            ),
        ],
      ),

      body: Column(
        children: [
          // ======================================================
          // 日期
          // ======================================================

          InkWell(
            onTap: _selectDate,
            child: Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .calendar_today_outlined,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Text(
                    DateFormat(
                      'yyyy/MM/dd',
                    ).format(_date),
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),

                  const Spacer(),

                  const Icon(
                    Icons
                        .arrow_drop_down,
                  ),
                ],
              ),
            ),
          ),

          const Divider(
            height: 1,
          ),

          // ======================================================
          // 標題
          // ======================================================

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            child: TextField(
              controller:
                  _titleController,
              textInputAction:
                  TextInputAction.next,
              decoration:
                  const InputDecoration(
                hintText: '標題',
                border:
                    InputBorder.none,
              ),
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          // ======================================================
          // 內容
          // ======================================================

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: TextField(
                controller:
                    _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical:
                    TextAlignVertical.top,
                decoration:
                    const InputDecoration(
                  hintText:
                      '今天發生了什麼？',
                  border:
                      InputBorder.none,
                ),
                style:
                    const TextStyle(
                  fontSize: 17,
                  height: 1.6,
                ),
              ),
            ),
          ),

          // ======================================================
          // 儲存按鈕
          // ======================================================

          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child: SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      _saving
                          ? null
                          : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.save,
                        ),
                  label: Text(
                    _saving
                        ? '儲存中...'
                        : '儲存日記',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

