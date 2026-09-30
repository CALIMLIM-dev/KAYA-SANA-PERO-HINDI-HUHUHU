import 'package:flutter/foundation.dart';

/*
    Whether the last request reached the server.

    Not a connectivity check. The phone can hold a full wifi bar on a router
    with no route out, and a captive portal at a coffee shop answers every
    request with its own login page - both of those read as "connected" to
    anything that asks the operating system, and neither can load a job feed.
    What actually matters is whether the app's own requests are getting
    through, and ApiClient already sees every one of them.

    So this is set from the one place that knows: a request that failed with
    no reply marks it offline, and the next request that gets any reply at all
    - including a refusal, which still proves the server was reachable -
    marks it back on.

    One value, listened to once, above the navigator. Otherwise every screen
    needs its own copy of "am I offline" and they disagree the moment one of
    them is not on top.
*/
class ConnectionStatus extends ValueNotifier<bool> {
  ConnectionStatus._() : super(false);

  static final ConnectionStatus instance = ConnectionStatus._();

  /// True when the last attempt got no reply.
  bool get isOffline => value;

  /// A request came back with nothing. Called by ApiClient.
  void markOffline() {
    if (!value) value = true;
  }

  /// A request came back with something, so the server is reachable.
  void markOnline() {
    if (value) value = false;
  }

  /// Lets a test start from a known state, since this is a singleton.
  @visibleForTesting
  void reset() => value = false;
}
