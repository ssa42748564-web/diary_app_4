import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'diary_edit_page.dart';
import 'models.dart';
import 'providers.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() =>
      _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  // ============================================================
  // 分頁設定
  // ============================================================

  static const int _pageSize = 50;

  final TextEditingController _controller =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final List<Diary> _results = [];

  DateTime? _startDate;
  DateTime? _endDate;

  int _offset = 0;

  bool _searched = false;
  bool _loading = false;
  bool _hasMore = true;

  // ============================================================
  // 初始化
  // ============================================================

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(
      _onScroll,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
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

    // 距離底部 300px 時預先載入
    if (position.pixels >=
        position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  // ============================================================
  // 開始搜尋
  // ============================================================

  Future<void> _search() async {
    if (_loading) {
      return;
    }

    // ------------------------------------------------------------
    // 日期檢查
    // ------------------------------------------------------------

    if (_startDate != null &&
        _endDate != null &&
        _startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('開始日期不能晚於結束日期'),
        ),
      );

      return;
    }

    setState(() {
      _searched = true;
      _loading = true;

      _offset = 0;
      _hasMore = true;

      _results.clear();
    });

    try {
      final repository =
          ref.read(diaryRepositoryProvider);

      final result =
          await repository.searchPageWithDateRange(
        keyword: _controller.text.trim(),
        start: _startDate,
        end: _endDate,
        limit: _pageSize,
        offset: 0,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _results.addAll(result);

        _offset = result.length;

        // 少於 50 筆 = 已經沒有下一頁
        _hasMore =
            result.length == _pageSize;

        _loading = false;
      });

      // 每次重新搜尋後回到最上面
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('搜尋失敗：$e'),
        ),
      );
    }
  }

  // ============================================================
  // 載入下一頁
  // ============================================================

  Future<void> _loadMore() async {
    if (_loading || !_hasMore || !_searched) {
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final repository =
          ref.read(diaryRepositoryProvider);

      final result =
          await repository.searchPageWithDateRange(
        keyword: _controller.text.trim(),
        start: _startDate,
        end: _endDate,
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _results.addAll(result);

        _offset += result.length;

        _hasMore =
            result.length == _pageSize;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('載入更多失敗：$e'),
        ),
      );
    }
  }

  // ============================================================
  // 選擇開始日期
  // ============================================================

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDate:
          _startDate ?? _endDate ?? DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _startDate = selected;
    });

    // 如果已經搜尋過，日期改變後立即重新搜尋
    if (_searched) {
      await _search();
    }
  }

  // ============================================================
  // 選擇結束日期
  // ============================================================

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      initialDate:
          _endDate ?? _startDate ?? DateTime.now(),
    );

    if (selected == null) {
      return;
    }

    setState(() {
      _endDate = selected;
    });

    // 如果已經搜尋過，日期改變後立即重新搜尋
    if (_searched) {
      await _search();
    }
  }

  // ============================================================
  // 清除搜尋條件
  // ============================================================

  void _clearFilters() {
    setState(() {
      _controller.clear();

      _startDate = null;
      _endDate = null;

      _results.clear();

      _offset = 0;
      _hasMore = true;

      _searched = false;
      _loading = false;
    });

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  // ============================================================
  // 編輯後重新搜尋
  // ============================================================

  Future<void> _reloadSearch() async {
    if (!_searched) {
      return;
    }

    await _search();
  }

  // ============================================================
  // 月份分組
  // ============================================================

  Map<String, List<Diary>> _groupByMonth() {
    final groups = <String, List<Diary>>{};

    for (final diary in _results) {
      final key = DateFormat(
        'yyyy.MM',
        'zh_TW',
      ).format(diary.date);

      groups.putIfAbsent(
        key,
        () => [],
      );

      groups[key]!.add(diary);
    }

    return groups;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final groups = _groupByMonth();

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜尋日記'),
        actions: [
          IconButton(
            onPressed: _clearFilters,
            icon: const Icon(
              Icons.clear_all,
            ),
            tooltip: '清除搜尋',
          ),
        ],
      ),
      body: Column(
        children: [
          // ======================================================
          // 關鍵字
          // ======================================================

          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              textInputAction:
                  TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '搜尋標題或內容',
                prefixIcon: const Icon(
                  Icons.search,
                ),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(
                    Icons.arrow_forward,
                  ),
                  tooltip: '搜尋',
                ),
                border:
                    const OutlineInputBorder(),
              ),
            ),
          ),

          // ======================================================
          // 日期條件
          // ======================================================

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _pickStartDate,
                    icon: const Icon(
                      Icons.calendar_today,
                    ),
                    label: Text(
                      _startDate == null
                          ? '開始日期'
                          : DateFormat(
                              'yyyy/MM/dd',
                            ).format(
                              _startDate!,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _pickEndDate,
                    icon: const Icon(
                      Icons.calendar_today,
                    ),
                    label: Text(
                      _endDate == null
                          ? '結束日期'
                          : DateFormat(
                              'yyyy/MM/dd',
                            ).format(
                              _endDate!,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ======================================================
          // 搜尋結果
          // ======================================================

          Expanded(
            child: _buildResults(groups),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 搜尋結果區域
  // ============================================================

  Widget _buildResults(
    Map<String, List<Diary>> groups,
  ) {
    // ------------------------------------------------------------
    // 尚未搜尋
    // ------------------------------------------------------------

    if (!_searched) {
      return const Center(
        child: Text(
          '輸入關鍵字或選擇日期開始搜尋',
        ),
      );
    }

    // ------------------------------------------------------------
    // 第一次搜尋中
    // ------------------------------------------------------------

    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // ------------------------------------------------------------
    // 沒找到
    // ------------------------------------------------------------

    if (_results.isEmpty) {
      return RefreshIndicator(
        onRefresh: _search,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text('找不到日記'),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------
    // 有結果
    // ------------------------------------------------------------

    return RefreshIndicator(
      onRefresh: _search,
      child: ListView(
        controller: _scrollController,
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          12,
          4,
          12,
          24,
        ),
        children: [
          // --------------------------------------------------------
          // 月份分組
          // --------------------------------------------------------

          for (final entry in groups.entries) ...[
            _MonthHeader(
              month: entry.key,
              count: entry.value.length,
            ),

            for (final diary in entry.value)
              _SearchDiaryItem(
                key: ValueKey(
                  diary.id,
                ),
                diary: diary,
                onChanged:
                    _reloadSearch,
              ),
          ],

          // --------------------------------------------------------
          // 底部載入狀態
          // --------------------------------------------------------

          if (_loading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (!_hasMore)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
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
  Widget build(
    BuildContext context,
  ) {
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
                  fontWeight:
                      FontWeight.bold,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 2,
            ),
            decoration:
                BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
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
// 搜尋結果日記
// ================================================================

class _SearchDiaryItem
    extends StatelessWidget {
  final Diary diary;
  final Future<void> Function() onChanged;

  const _SearchDiaryItem({
    super.key,
    required this.diary,
    required this.onChanged,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),

        // ========================================================
        // 標題
        // ========================================================

        title: Row(
          children: [
            if (diary.isFavorite)
              const Padding(
                padding:
                    EdgeInsets.only(
                  right: 5,
                ),
                child: Icon(
                  Icons.star,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
            Expanded(
              child: Text(
                diary.title.isEmpty
                    ? '無標題'
                    : diary.title,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // ========================================================
        // 日期 + 內容
        // ========================================================

        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            '${DateFormat('yyyy/MM/dd').format(diary.date)}\n'
            '${diary.content.replaceAll('\n', ' ')}',
            maxLines: 2,
            overflow:
                TextOverflow.ellipsis,
          ),
        ),

        isThreeLine: true,

        // ========================================================
        // 點擊 → 編輯
        // ========================================================

        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DiaryEditPage(
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