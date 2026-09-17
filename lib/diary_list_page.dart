import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'diary_edit_page.dart';
import 'models.dart';
import 'providers.dart';

class DiaryListPage extends ConsumerStatefulWidget {
  const DiaryListPage({super.key});

  @override
  ConsumerState<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends ConsumerState<DiaryListPage> {
  // ============================================================
  // 分頁設定
  // ============================================================

  static const int _pageSize = 50;

  final ScrollController _scrollController = ScrollController();

  final List<Diary> _diaries = [];

  int _offset = 0;

  bool _isLoading = false;
  bool _hasMore = true;
  bool _initialized = false;

  // ============================================================
  // 初始化
  // ============================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFirstPage();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // 滾動到底部 → 載入下一頁
  // ============================================================

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    // 距離底部 300px 就開始預先載入
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // ============================================================
  // 第一次載入 / 重新整理
  // ============================================================

  Future<void> _loadFirstPage() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMore = true;
      _diaries.clear();
      _initialized = true;
    });

    try {
      final repository = ref.read(diaryRepositoryProvider);

      final result = await repository.getPage(
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _diaries.addAll(result);

        _offset = result.length;

        _hasMore = result.length == _pageSize;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('讀取失敗：$e'),
        ),
      );
    }
  }

  // ============================================================
  // 載入下一頁
  // ============================================================

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final repository = ref.read(diaryRepositoryProvider);

      final result = await repository.getPage(
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _diaries.addAll(result);

        _offset += result.length;

        // 如果這次不足 50 筆，代表已經到底
        _hasMore = result.length == _pageSize;

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('載入更多失敗：$e'),
        ),
      );
    }
  }

  // ============================================================
  // 下拉重新整理
  // ============================================================

  Future<void> _refresh() async {
    await _loadFirstPage();
  }

  // ============================================================
  // 編輯 / 收藏 / 刪除後重新整理
  // ============================================================

  Future<void> _reloadAfterChanged() async {
    await _loadFirstPage();
  }

  // ============================================================
  // 月份分組
  // ============================================================

  Map<String, List<Diary>> _groupByMonth() {
    final groups = <String, List<Diary>>{};

    for (final diary in _diaries) {
      final key = DateFormat(
        'yyyy.MM',
        'zh_TW',
      ).format(diary.date);

      groups.putIfAbsent(key, () => []);
      groups[key]!.add(diary);
    }

    return groups;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final groups = _groupByMonth();

    return Scaffold(
      appBar: AppBar(
        title: const Text('全部日記'),
      ),
      body: _buildBody(groups),
    );
  }

  Widget _buildBody(
    Map<String, List<Diary>> groups,
  ) {
    // 第一次載入
    if (_isLoading && _diaries.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 沒有資料
    if (_diaries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 250),
            Center(
              child: Text('目前沒有日記'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          12,
          12,
          12,
          24,
        ),
        children: [
          for (final entry in groups.entries) ...[
            _MonthHeader(
              month: entry.key,
              count: entry.value.length,
            ),
            for (final diary in entry.value)
              _DiaryItem(
                key: ValueKey(diary.id),
                diary: diary,
                onChanged: _reloadAfterChanged,
              ),
          ],

          // ======================================================
          // 底部載入提示
          // ======================================================

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (!_hasMore)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child: Text(
                  '已經到底了',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// 月份標題
// ================================================================

class _MonthHeader extends StatelessWidget {
  final String month;
  final int count;

  const _MonthHeader({
    required this.month,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        16,
        4,
        8,
      ),
      child: Row(
        children: [
          Text(
            month,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count 篇',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// 日記項目
// ================================================================

class _DiaryItem extends ConsumerWidget {
  final Diary diary;
  final Future<void> Function() onChanged;

  const _DiaryItem({
    super.key,
    required this.diary,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),

        // ========================================================
        // 日期
        // ========================================================

        leading: SizedBox(
          width: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MM/dd').format(diary.date),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // ========================================================
        // 標題
        // ========================================================

        title: Row(
          children: [
            if (diary.isFavorite) ...[
              const Icon(
                Icons.star,
                size: 18,
                color: Colors.amber,
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                diary.title.isEmpty
                    ? '無標題'
                    : diary.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // ========================================================
        // 內容預覽
        // ========================================================

        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            diary.content.replaceAll('\n', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // ========================================================
        // 選單
        // ========================================================

        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            final repository =
                ref.read(diaryRepositoryProvider);

            try {
              // --------------------------------------------------
              // 收藏
              // --------------------------------------------------

              if (value == 'favorite') {
                await repository.toggleFavorite(
                  diary.id!,
                  !diary.isFavorite,
                );

                await onChanged();
              }

              // --------------------------------------------------
              // 刪除
              // --------------------------------------------------

              if (value == 'delete') {
                await repository.delete(
                  diary.id!,
                );

                await onChanged();
              }
            } catch (e) {
              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                SnackBar(
                  content: Text(
                    '操作失敗：$e',
                  ),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'favorite',
              child: Row(
                children: [
                  Icon(
                    diary.isFavorite
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    diary.isFavorite
                        ? '取消收藏'
                        : '加入收藏',
                  ),
                ],
              ),
            ),

            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                  ),
                  SizedBox(width: 8),
                  Text('刪除'),
                ],
              ),
            ),
          ],
        ),

        // ========================================================
        // 點擊 → 編輯
        // ========================================================

        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiaryEditPage(
                diary: diary,
              ),
            ),
          );

          if (!context.mounted) {
            return;
          }

          await onChanged();
        },
      ),
    );
  }
}