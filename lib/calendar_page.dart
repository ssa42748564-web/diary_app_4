import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import 'diary_edit_page.dart';
import 'models.dart';
import 'providers.dart';

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() =>
      _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Diary> _selectedDiaries = [];

  Future<void> _loadDay(DateTime day) async {
    final items = await ref
        .read(diaryRepositoryProvider)
        .getByDate(day);

    if (!mounted) return;

    setState(() {
      _selectedDiaries = items;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadDay(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('日曆'),
      ),
      body: Column(
        children: [
        TableCalendar<Diary>(
          locale: 'zh_TW',
          calendarFormat: CalendarFormat.month,
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
          ),
          firstDay: DateTime(1900),
          lastDay: DateTime(2200),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) {
            return isSameDay(
              day,
              _selectedDay,
            );
          },
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });

            _loadDay(selectedDay);
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('yyyy/MM/dd').format(
                  _selectedDay,
                ),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge,
              ),
            ),
          ),
          Expanded(
            child: _selectedDiaries.isEmpty
                ? const Center(
                    child: Text('這一天沒有日記'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    itemCount: _selectedDiaries.length,
                    itemBuilder: (context, index) {
                      final diary =
                          _selectedDiaries[index];

                      return Card(
                        child: ListTile(
                          title: Text(
                            diary.title.isEmpty
                                ? '無標題'
                                : diary.title,
                          ),
                          subtitle: Text(
                            diary.content.replaceAll(
                              '\n',
                              ' ',
                            ),
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                          ),
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
                                builder: (_) =>
                                    DiaryEditPage(
                                  diary: diary,
                                ),
                              ),
                            );

                            _loadDay(_selectedDay);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}