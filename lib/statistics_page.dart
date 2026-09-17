import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class StatisticsPage extends ConsumerStatefulWidget {
  const StatisticsPage({super.key});

  @override
  ConsumerState<StatisticsPage> createState() =>
      _StatisticsPageState();
}

class _StatisticsPageState
    extends ConsumerState<StatisticsPage> {
  int? _total;
  int? _year;
  int? _month;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository =
        ref.read(diaryRepositoryProvider);

    final now = DateTime.now();

    final total =
        await repository.getTotalCount();

    final year =
        await repository.getYearCount(now.year);

    final month =
        await repository.getMonthCount(
      now.year,
      now.month,
    );

    if (!mounted) return;

    setState(() {
      _total = total;
      _year = year;
      _month = month;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('統計'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            icon: Icons.menu_book,
            title: '全部日記',
            value: '${_total ?? 0}',
            unit: '篇',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.calendar_today,
            title: '今年',
            value: '${_year ?? 0}',
            unit: '篇',
          ),
          const SizedBox(height: 12),
          _StatCard(
            icon: Icons.today,
            title: '本月',
            value: '${_month ?? 0}',
            unit: '篇',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              icon,
              size: 40,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.baseline,
                    textBaseline:
                        TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(unit),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}