import 'package:flutter/material.dart';
import 'alarms.dart';
import 'data.dart';
import 'main.dart';

class BellButton extends StatelessWidget {
  const BellButton({super.key});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => const AlarmSheet(),
        ),
        child: const Glass(
          radius: 20,
          padding: EdgeInsets.all(12),
          child: Icon(Icons.alarm, color: kTeal),
        ),
      );
}

class AlarmSheet extends StatefulWidget {
  const AlarmSheet({super.key});
  @override
  State<AlarmSheet> createState() => _AlarmSheetState();
}

class _AlarmSheetState extends State<AlarmSheet> {
  AlarmStatus? _st;
  String _note = '';
  bool _noteOk = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AlarmService.status();
    if (mounted) setState(() => _st = s);
  }

  Future<void> _perms() async {
    await AlarmService.requestPermissions();
  }

  Future<void> _reschedule() async {
    final c = await ScheduleService.loadCached();
    if (c == null) {
      setState(() {
        _noteOk = false;
        _note = 'ما في جدول محفوظ. افتح التطبيق مع إنترنت أول مرة.';
      });
      return;
    }
    final o = await AlarmService.ensureScheduled(c, force: true);
    setState(() {
      if (o.planned == 0) {
        _noteOk = true;
        _note = 'ما في دروس لجدولتها.';
      } else if (o.ok) {
        _noteOk = o.warning == null;
        _note = 'تمت جدولة ${o.scheduled} منبه';
      } else {
        _noteOk = false;
        _note = o.warning ?? 'فشلت الجدولة';
      }
    });
  }

  Future<void> _test() async {
    final err = await AlarmService.test();
    setState(() {
      _noteOk = err == null;
      _note = err == null
          ? 'رح يرن بعد 10 ثواني. اقفل الشاشة وجرب.'
          : 'فشلت التجربة: $err';
    });
  }

  Widget _row(String t, bool ok) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(ok ? Icons.check_circle : Icons.error_outline,
                color: ok ? kTeal : kGold, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(t)),
          ],
        ),
      );

  Widget _warn(String t) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(t, style: const TextStyle(fontSize: 12, color: kGold)),
      );

  Widget _btn(String t, IconData i, Color c, Future<void> Function() f) =>
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GestureDetector(
          onTap: () async {
            await f();
            await _load();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: c.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(i, color: c, size: 20),
                const SizedBox(width: 8),
                Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = _st;
    final last = AlarmService.last;
    final dataErr = ScheduleService.lastError;
    String pendingText = '';
    bool pendingOk = false;
    if (s != null) {
      pendingText = 'منبهات مجدولة: ${s.pending}';
      pendingOk = s.pending > 0;
      if (last != null && last.planned != s.pending) {
        pendingText = 'منبهات مجدولة: ${s.pending} من ${last.planned}';
        pendingOk = false;
      }
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Glass(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('المنبهات',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (s == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator(color: kGold)),
                )
              else ...[
                _row('صلاحية الإشعارات', s.notifications),
                _row('المنبهات الدقيقة', s.exact),
                _row(pendingText, pendingOk),
              ],
              if (last != null && last.warning != null) _warn(last.warning!),
              if (dataErr != null) _warn(dataErr),
              _btn('تفعيل الصلاحيات', Icons.lock_open, kGold, _perms),
              _btn('إعادة جدولة المنبهات', Icons.sync, kTeal, _reschedule),
              _btn('تجربة منبه بعد 10 ثواني', Icons.notifications_active,
                  kPurple, _test),
              if (_note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_note,
                      style: TextStyle(color: _noteOk ? kTeal : kGold)),
                ),
              const SizedBox(height: 14),
              Text(
                'مهم: من إعدادات الجوال ← التطبيقات ← NOON ← البطارية، '
                'اختر "بدون قيود" حتى ما يوقف النظام المنبه.',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
