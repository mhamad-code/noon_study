import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

Future<void> _saveSource(String name) async {
  try {
    final p = await SharedPreferences.getInstance();
    await p.setString('last_src', name);
  } catch (_) {}
}

String _name(String url) {
  if (url.contains('api.github.com')) return 'GitHub API';
  if (url.contains('raw.githubusercontent.com')) return 'GitHub Raw';
  return 'jsDelivr (نسخة مخزنة وممكن تتأخر ساعات)';
}

/// بيجرب أكتر من عنوان لنفس الملف (بعض الشبكات بتحجب بعض نطاقات GitHub)
Future<http.Response> downloadUpdate() async {
  http.Response? last;
  String apiNote = '';
  final bust = DateTime.now().millisecondsSinceEpoch;
  for (final url in updateUrls) {
    final isApi = url.contains('api.github.com');
    final isRaw = url.contains('raw.githubusercontent.com');
    try {
      final u = isApi ? '$url&t=$bust' : (isRaw ? '$url?t=$bust' : url);
      final headers = <String, String>{
        if (isApi) 'Accept': 'application/vnd.github.raw+json',
        'Cache-Control': 'no-cache',
      };
      final r = await http
          .get(Uri.parse(u), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        await _saveSource(_name(url) + apiNote);
        return r;
      }
      if (isApi) apiNote = ' (API رجّع ${r.statusCode})';
      last = r;
    } catch (_) {
      if (isApi) apiNote = ' (API ما انفتح)';
    }
  }
  if (last != null) return last;
  throw Exception('no network');
}
