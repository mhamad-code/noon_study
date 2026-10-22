import 'dart:ui';
import 'package:flutter/material.dart';
import 'data.dart';

const kGold = Color(0xFFFFB23E);
const kPurple = Color(0xFFB892FF);
const kTeal = Color(0xFF5EEAD4);
const kBg1 = Color(0xFF1B1230);
const kBg2 = Color(0xFF221533);

void main() => runApp(const NoonApp());

class NoonApp extends StatelessWidget {
  const NoonApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NOON',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: kBg1,
          colorScheme: const ColorScheme.dark(
            primary: kGold,
            secondary: kPurple,
            tertiary: kTeal,
          ),
        ),
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const HomePage(),
      );
}

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: child,
          ),
        ),
      );
}

class _Glow extends StatelessWidget {
  final double? top, left, right, bottom;
  final double size;
  final Color color;
  const _Glow({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Positioned(
        top: top,
        left: left,
        right: right,
        bottom: bottom,
        child: IgnorePointer(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.35), color.withOpacity(0)],
              ),
            ),
          ),
        ),
      );
}

int _min(String t) {
  final p = t.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  Schedule? _schedule;
  bool _loading = false;
  bool _failed = false;
  int _day = DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _init() async {
    final cached = await ScheduleService.loadCached();
    if (mounted && cached != null) setState(() => _schedule = cached);
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    final fresh = await ScheduleService.fetchRemote();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = fresh == null;
      if (fresh != null) _schedule = fresh;
    });
  }

  String _status() {
    if (_loading) return 'جاري التحديث…';
    if (_schedule == null) return _failed ? 'تعذر تحميل الجدول' : '';
    if (_failed) return 'بدون إنترنت · النسخة المحفوظة v${_schedule!.version}';
    return 'محدّث · النسخة v${_schedule!.version}';
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(
                      colors: [kGold, kPurple, kTeal],
                    ).createShader(r),
                    child: const Text(
                      'NOON',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    _status(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _refresh,
              child: Glass(
                radius: 20,
                padding: const EdgeInsets.all(12),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kGold),
                      )
                    : const Icon(Icons.refresh, color: kGold),
              ),
            ),
          ],
        ),
      );

  Widget _dayChips() {
    final today = DateTime.now().weekday % 7;
    return SizedBox(
      height: 54,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final sel = i == _day;
          return GestureDetector(
            onTap: () => setState(() => _day = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(colors: [kGold, kPurple])
                    : null,
                color: sel ? null : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: sel
                      ? Colors.transparent
                      : (i == today ? kTeal : Colors.white.withOpacity(0.18)),
                ),
                boxShadow: sel
                    ? [BoxShadow(color: kGold.withOpacity(0.4), blurRadius: 14)]
                    : null,
              ),
              child: Text(
                dayNames[i],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: sel ? kBg1 : Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _msg(String t) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Glass(
          padding: const EdgeInsets.all(24),
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8)),
          ),
        ),
      );

  List<Widget> _items() {
    if (_schedule == null) {
      return [
        _msg(_loading
            ? 'جاري تحميل الجدول…'
            : 'ما قدرت أحمّل الجدول. تأكد من الإنترنت واسحب للتحديث.')
      ];
    }
    final lessons = _schedule!.week[dayKeys[_day]] ?? <Lesson>[];
    if (lessons.isEmpty) return [_msg('ما في دروس ${dayNames[_day]} 🌤️')];

    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final isToday = _day == now.weekday % 7;

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
        child: Text(
          '${dayNames[_day]} · ${lessons.length} دروس',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ),
      for (int i = 0; i < lessons.length; i++)
        LessonCard(
          key: ValueKey('$_day-$i-${lessons[i].subject}'),
          lesson: lessons[i],
          index: i,
          live: isToday &&
              nowMin >= _min(lessons[i].start) &&
              nowMin < _min(lessons[i].end),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kBg1, kBg2],
              ),
            ),
          ),
          const _Glow(top: -80, right: -60, size: 260, color: kGold),
          const _Glow(top: 300, left: -120, size: 300, color: kPurple),
          const _Glow(bottom: -100, right: -40, size: 240, color: kTeal),
          SafeArea(
            child: Column(
              children: [
                _header(),
                _dayChips(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: kGold,
                    backgroundColor: kBg2,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: _items(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LessonCard extends StatelessWidget {
  final Lesson lesson;
  final int index;
  final bool live;
  const LessonCard({
    super.key,
    required this.lesson,
    required this.index,
    required this.live,
  });

  @override
  Widget build(BuildContext context) {
    final color = [kGold, kPurple, kTeal][index % 3];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (c, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Glass(
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.6), blurRadius: 10)
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lesson.subject,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (live)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: kTeal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: kTeal),
                              ),
                              child: const Text(
                                'الآن',
                                style: TextStyle(fontSize: 12, color: kTeal),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 16, color: color),
                          const SizedBox(width: 6),
                          Text('${lesson.start} – ${lesson.end}'),
                        ],
                      ),
                      if (lesson.pages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book, size: 15, color: color),
                              const SizedBox(width: 6),
                              Text(lesson.pages,
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
