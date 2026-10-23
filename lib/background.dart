import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'alarms.dart';
import 'data.dart';

/// بتشتغل بالخلفية: بتحمّل الجدول وبتحدّث المنبهات إذا تغيّر
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      await AlarmService.init();
      final remote = await ScheduleService.fetchRemote();
      final s = remote ?? await ScheduleService.loadCached();
      if (s != null) await AlarmService.ensureScheduled(s);
      final p = await SharedPreferences.getInstance();
      await p.setString('bg_last', DateTime.now().toIso8601String());
      await p.setInt('bg_count', (p.getInt('bg_count') ?? 0) + 1);
      if (remote != null) await p.setInt('bg_ver', remote.version);
    } catch (_) {}
    return true;
  });
}

Future<void> setupBackground() async {
  try {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'noon-refresh',
      'refreshSchedule',
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {}
}

Future<String> backgroundInfo() async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final src = p.getString('last_src');
    final srcLine = src == null ? '' : '\nمصدر آخر تحميل: $src';
    final at = DateTime.tryParse(p.getString('bg_last') ?? '');
    if (at == null) return 'لم يعمل الفحص بالخلفية بعد$srcLine';
    final m = DateTime.now().difference(at).inMinutes;
    final when =
        m < 1 ? 'الآن' : (m < 60 ? 'منذ $m دقيقة' : 'منذ ${m ~/ 60} ساعة');
    final ver = p.getInt('bg_ver');
    final cnt = p.getInt('bg_count') ?? 0;
    final v = ver == null ? '' : ' (نسخة v$ver)';
    return 'آخر فحص بالخلفية: $when$v · عدد الفحوصات: $cnt$srcLine';
  } catch (_) {
    return 'لم يعمل الفحص بالخلفية بعد';
  }
}
