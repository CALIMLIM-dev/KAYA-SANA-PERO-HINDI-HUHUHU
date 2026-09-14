import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/services/api_client.dart';

/*
    Opens a worker's resume for an employer who may see it.

    The file sits behind an authenticated endpoint, so it cannot be handed
    to the browser as a URL - a link carries no bearer token and lands on a
    401. It is fetched through the same client every other call uses, written
    to the app's own cache, and opened with whatever the phone has for PDFs
    and images.

    The access rule lives on the server and is not repeated here: a 403 comes
    back as the server's own sentence, and that is what the employer reads.
    A worker uploaded this file for exactly this moment, and until now no
    screen ever showed it to anyone.
*/
class ResumeOpener {
  const ResumeOpener._();

  /// Downloads and opens. Returns null on success, or the reason it did not.
  static Future<String?> open(int workerId) async {
    try {
      final response = await ApiClient().getBytes('/workers/$workerId/resume');

      final name = _filenameFrom(response.headers.value('content-disposition'))
          ?? 'resume.pdf';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/resumes/$workerId-$name');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.data ?? const <int>[], flush: true);

      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        return 'Nothing on this phone can open a ${name.split('.').last.toUpperCase()} file.';
      }

      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// The name the worker uploaded, from `attachment; filename="Juan_CV.pdf"`.
  static String? _filenameFrom(String? disposition) {
    if (disposition == null) return null;
    final match = RegExp(r'filename\*?=(?:UTF-8'')?"?([^";]+)"?').firstMatch(disposition);
    final raw = match?.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    // Keep it a plain file name: no path pieces from the header.
    return raw.replaceAll(RegExp(r'[\\/]'), '_');
  }
}
