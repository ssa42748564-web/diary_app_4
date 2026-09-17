import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'diary_edit_page.dart';
import 'diary_list_page.dart';
import 'providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaries = ref.watch(recentDiaryProvider);
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的日記'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentDiaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              DateFormat('yyyy 年 MM 月 dd 日').format(today),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE', 'zh_TW').format(today),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DiaryEditPage(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 40),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '寫下今天',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text('記錄今天發生的事情'),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '最近日記',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DiaryListPage(),
                      ),
                    );
                  },
                  child: const Text('查看全部'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            diaries.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Text(
                '讀取失敗：$error',
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(
                        child: Text('目前還沒有日記'),
                      ),
                    ),
                  );
                }

                return Column(
                  children: items.map((diary) {
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.article_outlined),
                        title: Text(
                          diary.title.isEmpty
                              ? '無標題'
                              : diary.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DateFormat('yyyy/MM/dd').format(diary.date)}\n'
                          '${diary.content.replaceAll('\n', ' ')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        isThreeLine: true,
                        trailing: diary.isFavorite
                            ? const Icon(
                                Icons.star,
                                color: Colors.amber,
                              )
                            : null,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DiaryEditPage(
                                diary: diary,
                              ),
                            ),
                          );

                          ref.invalidate(recentDiaryProvider);
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}