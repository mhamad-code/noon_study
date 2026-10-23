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
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {}
}

Future<String> backgroundInfo() async {
  const none = 'لم يعمل الفحص بالخلفية بعد';
  try {
    final p = await SharedPreferences.getInstance();
    await p.reload();
    final at = DateTime.tryParse(p.getString('bg_last') ?? '');
    if (at == null) return none;
    final m = DateTime.now().difference(at).inMinutes;
    final when = m < 1 ? 'الآن' : (m < 60 ? 'منذ $m دقيقة' : 'منذ ${m ~/ 60} ساعة');
    final ver = p.getInt('bg_ver');
    return 'آخر فحص بالخلفية: $when${ver == null ? '' : ' (نسخة v$ver)'}';
  } catch (_) {
    return none;
  }
}
