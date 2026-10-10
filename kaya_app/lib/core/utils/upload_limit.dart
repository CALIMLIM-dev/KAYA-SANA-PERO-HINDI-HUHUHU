/*
    What one request may carry to the server.

    nginx refuses a body over 1 MB on the live server, before Laravel's own
    5 MB rule is ever read, and answers with an HTML page. Files the app
    cannot shrink - a PDF, a document picked as a file - are checked here
    when they are chosen instead of failing after the upload. Leaves room
    for the form fields around the file; see PostJobScreen for how the
    limit was measured.
*/
const int kMaxUploadBytes = 900 * 1024;

/// The sentence for a file over [kMaxUploadBytes], or null when it fits.
String? uploadTooLarge(int bytes) {
  if (bytes <= kMaxUploadBytes) return null;
  final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
  return 'That file is $mb MB. Files must be under 1 MB. '
      'A photo of the paper usually fits.';
}
