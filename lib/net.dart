import 'package:http/http.dart' as http;
import 'config.dart';

/// بيجرب أكتر من عنوان لنفس الملف (بعض الشبكات بتحجب بعض نطاقات GitHub)
Future<http.Response> downloadUpdate() async {
  http.Response? last;
  for (final url in updateUrls) {
    try {
      final headers = url.contains('api.github.com')
          ? {'Accept': 'application/vnd.github.raw+json'}
          : <String, String>{};
      final r = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return r;
      last = r;
    } catch (_) {}
  }
  if (last != null) return last;
  throw Exception('no network');
}
