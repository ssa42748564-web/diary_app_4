import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日期 Locale 資料
  await initializeDateFormatting('zh_TW');

  if (kIsWeb) {
    // Chrome / Web
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    // Windows / Linux / macOS
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Android / iOS
  // 不設定 databaseFactory，使用原生 sqflite。

  runApp(
    const ProviderScope(
      child: DiaryApp(),
    ),
  );
}