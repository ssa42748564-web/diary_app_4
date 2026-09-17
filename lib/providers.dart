import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepository();
});

final diaryListProvider =
    FutureProvider.autoDispose<List<Diary>>((ref) async {
  return ref.watch(diaryRepositoryProvider).getAll();
});

final recentDiaryProvider =
    FutureProvider.autoDispose<List<Diary>>((ref) async {
  return ref.watch(diaryRepositoryProvider).getRecent();
});

final templateListProvider =
    FutureProvider.autoDispose<List<DiaryTemplate>>((ref) async {
  return ref.watch(diaryRepositoryProvider).getTemplates();
});