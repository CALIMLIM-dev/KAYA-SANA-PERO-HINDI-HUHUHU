import 'dart:async';

import 'dart:io';

import 'package:dio/dio.dart' show FormData, MultipartFile;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_version.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/kaya_popup.dart';
import '../../../data/services/api_client.dart';

/*
    Writing to KAYA.

    The FAQ answers the questions somebody thought of in advance. This is for
    everything else: a rejected verification nobody explained, an application
    charged for a post that vanished, an account locked out. Before it there
    was nowhere to go but the app store review page.

    One thread that keeps going, which is what "chat to support" means to the
    person using it - not a ticket with a subject and a reference number.

    Polled while it is open, the same way the rest of the app does realtime.

    KAYA Assistant answers first, like a shop's help chat: a menu of topics,
    then the issue, then an answer that has already read the person's own
    records, with buttons that open the screen to fix it - and Yes, Solved,
    Talk to an Agent or back to the menu. Typing goes to the AI. An agent
    request joins a real line: the header shows the place and the wait, then
    who joined. Lines between the two sides show as dividers.
*/
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, this.seed, this.seedAssistant});

  /// Messages in place of the fetch, for a render test.
  final List<Map<String, dynamic>>? seed;

  /// The assistant's state in place of the fetch, for a render test.
  final Map<String, dynamic>? seedAssistant;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  /*
      Four seconds, not ten.

      Ten is how long somebody waiting for KAYA to answer sat looking at
      nothing, and it read as the message never arriving. The admin side of
      the same conversation polls every three; notifications poll every
      eight. This was the slowest thing in the app and the one with a person
      waiting at both ends.
  */
  static const Duration _pollEvery = Duration(seconds: 4);

  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  // KAYA Assistant, as the server last described it.
  bool _assistantOn = false;
  bool _withPerson = false;
  bool _handingOff = false;
  bool _choosing = false;

  // The greeting and its menu, the line and the agent, as the server says.
  String _greeting = '';
  List<Map<String, dynamic>> _menu = const [];
  Map<String, dynamic>? _line;
  String? _agent;
  bool _teamOnline = true;

  /*
      Answers from KAYA Assistant that arrived while the screen was open are
      written out word by word, the way a chat assistant types. What was
      already there when the screen opened shows at once: nobody wants to
      sit through yesterday's answers being typed again.
  */
  final Set<int> _typedIds = {};
  bool _opened = false;

  void _typeOut(Iterable<Map<String, dynamic>> incoming) {
    if (!_opened) return;
    final known = {for (final m in _messages) m['id']};
    for (final m in incoming) {
      final id = m['id'];
      if (m['from_assistant'] == true && id is int && !known.contains(id)) {
        _typedIds.add(id);
      }
    }
  }

  /// Set after sending while the assistant is answering: shows the typing
  /// line until its answer arrives, or for a minute at most.
  DateTime? _awaitingSince;
  int _awaitingAfter = 0;

  @override
  void initState() {
    super.initState();

    final seed = widget.seed;

    if (seed != null) {
      _messages = seed;
      _loading = false;
      _readAssistant(widget.seedAssistant);

      return;
    }

    _load();
    _poll = Timer.periodic(_pollEvery, (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    /*
        Leaving ends the chat: the server erases it, unless it is still
        waiting for the team or holds a team reply not yet read. Nothing to
        wait for here, and a failure only means it is erased on the next
        open instead.
    */
    if (widget.seed == null && _opened) {
      unawaited(_api.post('/support/end').then((_) {}, onError: (_) {}));
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// One read at a time: a slow poll overlapping the next appended the
  /// same new lines twice.
  bool _fetching = false;

  /// Adds rows by id, so a poll and a send carrying the same message show it
  /// once. Ordered by id, which is the order they were written.
  List<Map<String, dynamic>> _merged(List<Map<String, dynamic>> incoming) {
    final byId = <Object?, Map<String, dynamic>>{
      for (final m in _messages) m['id']: m,
      for (final m in incoming) m['id']: m,
    };
    return byId.values.toList()
      ..sort((a, b) => ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0));
  }

  Future<void> _load({bool quiet = false}) async {
    if (_fetching) return;
    if (await ApiClient.getToken() == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    _fetching = true;
    try {
      /*
          Only what has not been seen, once there is something to compare to.

          This fetched the whole conversation on every poll. Speeding the poll
          up from ten seconds to four made that worse rather than better: the
          entire history was being re-sent every four seconds, over mobile
          data, to draw one new line. The admin side has asked this way since
          its polling was written.

          A cold open still asks for everything - `after` is only sent once a
          message id is known - and the server says which it answered, so
          there is no guessing about appending against replacing.
      */
      final since = _messages.isEmpty ? 0 : (_messages.last['id'] as int? ?? 0);

      final res = await _api.get(
        '/support',
        queryParameters: since > 0 ? {'after': since} : null,
      );

      final data = res.data['data'] as Map<String, dynamic>;

      if (!mounted) return;

      final incoming =
          ((data['messages'] as List?) ?? []).cast<Map<String, dynamic>>();
      final incremental = data['incremental'] == true;

      final before = (_assistantOn, _withPerson);
      _readAssistant(data['assistant'] as Map<String, dynamic>?);
      _settleAwaiting(incoming);
      final assistantChanged = before != (_assistantOn, _withPerson);

      // Nothing new on a cursored poll: leave the list alone rather than
      // rebuilding it, which would fight the scroll position.
      if (incremental && incoming.isEmpty) {
        if (_loading || _error != null || assistantChanged || _awaitingExpired()) {
          setState(() {
            _loading = false;
            _error = null;
          });
        }

        return;
      }

      setState(() {
        _typeOut(incoming);
        _messages = incremental ? _merged(incoming) : incoming;
        _loading = false;
        _error = null;
        _opened = true;
      });

      _toBottom();
    } catch (e) {
      if (!mounted || quiet) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    } finally {
      _fetching = false;
    }
  }

  void _readAssistant(Map<String, dynamic>? state) {
    if (state == null) return;
    _assistantOn = state['on'] == true;
    _withPerson = state['with_person'] == true;
    _greeting = '${state['greeting'] ?? ''}';
    _menu = ((state['menu'] as List?) ?? const [])
        .whereType<Map>()
        .map((q) => q.cast<String, dynamic>())
        .toList();
    _line = (state['line'] as Map?)?.cast<String, dynamic>();
    _agent = state['agent'] as String?;
    _teamOnline = state['team_online'] != false;
  }

  /// The typing line goes once KAYA has answered after the sent message.
  void _settleAwaiting(List<Map<String, dynamic>> incoming) {
    if (_awaitingSince == null) return;
    final answered = incoming.any((m) =>
        m['from_admin'] == true && ((m['id'] as int?) ?? 0) > _awaitingAfter);
    if (answered || _withPerson || !_assistantOn) _awaitingSince = null;
  }

  bool _awaitingExpired() {
    final since = _awaitingSince;
    if (since == null) return false;
    if (DateTime.now().difference(since) < const Duration(seconds: 60)) return false;
    _awaitingSince = null;
    return true;
  }

  bool get _assistantTyping => _awaitingSince != null;

  /*
      A tap in the assistant's menu: a topic, an issue, Yes Solved, Talk to
      an Agent. Something's Broken opens the report form instead.
  */
  Future<void> _choose(String key) async {
    if (key == 'topic:bug') {
      await _reportBug();
      return;
    }
    if (_choosing) return;
    setState(() => _choosing = true);

    try {
      final res = await _api.post('/support/choose', data: {'key': key});
      final data = res.data['data'] as Map<String, dynamic>;
      final incoming = ((data['messages'] as List?) ?? const []).cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _opened = true;
        _typeOut(incoming);
        _messages = _merged(incoming);
        _readAssistant(data['assistant'] as Map<String, dynamic>?);
        _choosing = false;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _choosing = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Something's Broken: where, what, a few words and a screenshot.
  Future<void> _reportBug() async {
    final sent = await showKayaPopup<Map<String, dynamic>>(
      context,
      builder: (_) => const _BugReportDialog(),
    );
    if (sent == null || !mounted) return;

    final message = (sent['message'] as Map?)?.cast<String, dynamic>();
    setState(() {
      _opened = true;
      if (message != null) _messages = _merged([message]);
    });
    _toBottom();
  }

  /// Back to KAYA Assistant, from the team.
  Future<void> _backToAssistant() async {
    if (_handingOff) return;
    setState(() => _handingOff = true);

    try {
      final res = await _api.post('/support/assistant');
      final data = res.data['data'] as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>?;

      if (!mounted) return;

      setState(() {
        if (message != null) _messages = _merged([message]);
        _readAssistant(data['assistant'] as Map<String, dynamic>?);
        _handingOff = false;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _handingOff = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);

    try {
      final res = await _api.post('/support', data: {'body': text});
      final message = res.data['data'] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _messages = _merged([message]);
        _sending = false;
        if (_assistantOn && !_withPerson) {
          _awaitingSince = DateTime.now();
          _awaitingAfter = (message['id'] as int?) ?? 0;
        }
      });

      _controller.clear();
      _toBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _sending = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Message KAYA', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_assistantOn)
              Text(
                _status(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.neutral500),
              ),
          ],
        ),
        actions: [
          // While waiting, back to the assistant keeps the place in line.
          if (_assistantOn && _withPerson && _agent == null)
            TextButton(
              onPressed: _handingOff ? null : _backToAssistant,
              child: const Text('Back to Assistant'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.neutral200)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_assistantOn && !_withPerson && _menu.isNotEmpty)
                    IconButton(
                      onPressed: _choosing || _menuShowing ? null : () => _choose('menu'),
                      icon: const Icon(Icons.apps_rounded),
                      color: AppColors.neutral500,
                      tooltip: 'Menu',
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'What can we help with?',
                        counterText: '',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppColors.neutral300)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppColors.neutral300)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppColors.primary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_rounded),
                    color: AppColors.primary,
                    tooltip: 'Send',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.neutral600),
          ),
        ),
      );
    }

    if (_messages.isEmpty) {
      if (_assistantOn && !_withPerson && _menu.isNotEmpty) {
        return ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          children: [
            _bubble({'from_admin': true, 'from': 'KAYA Assistant', 'body': _greeting}),
            _options(_menu),
            const SizedBox(height: 12),
            const Text(
              'This chat clears when you leave it.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.neutral400),
            ),
          ],
        );
      }

      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_outlined, size: 48, color: AppColors.neutral300),
              SizedBox(height: 14),
              Text(
                'Tell Us What Happened',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutral700),
              ),
              SizedBox(height: 6),
              Text(
                'Somebody at KAYA reads this and answers here. '
                'Say which account, job or payment it is about.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.neutral500),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length + (_assistantTyping ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _messages.length) return _typing();
        final m = _messages[i];
        if (m['kind'] == 'event') return _divider('${m['body']}');

        final payload = (m['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        final options = ((payload['options'] as List?) ?? const []).whereType<Map>()
            .map((o) => o.cast<String, dynamic>()).toList();
        final actions = ((payload['actions'] as List?) ?? const []).whereType<Map>()
            .map((o) => o.cast<String, dynamic>()).toList();
        // Choices only on the newest line: older ones are history.
        final newest = i == _messages.length - 1;

        // Stretched, so a bubble of the person's own sits on the right. Start
        // shrank the row to the bubble and left every message on the left.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bubble(m),
            if (actions.isNotEmpty) _actions(actions),
            if (options.isNotEmpty && newest && !_withPerson) _options(options),
          ],
        );
      },
    );
  }

  /// Who is answering, in the header.
  String _status() {
    if (_agent != null) return '$_agent from KAYA';
    if (_withPerson) {
      if (!_teamOnline) return 'The team is offline. We will reply when we are back.';
      final place = _line?['position'];
      final eta = _line?['eta_minutes'];
      if (place != null) return eta != null ? '#$place in line · about $eta min' : '#$place in line';
      return 'Waiting for a KAYA agent';
    }
    return 'KAYA Assistant';
  }

  /// A line between the two sides: "Ana from KAYA joined the chat."
  Widget _divider(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.neutral200)),
          Flexible(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(text, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.neutral500)),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.neutral200)),
        ],
      ),
    );
  }

  /// Choices to tap, under the assistant's line: one card, a row each.
  Widget _options(List<Map<String, dynamic>> options) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) const Divider(height: 1, color: AppColors.neutral200),
              InkWell(
                onTap: _choosing ? null : () => _choose('${o['key']}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${o['label']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _choosing ? AppColors.neutral400 : AppColors.primary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.neutral400),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Whether the topic menu is already the newest thing: Menu again would
  /// only repeat it.
  bool get _menuShowing {
    final shown = _messages.where((m) => m['kind'] != 'event');
    if (shown.isEmpty) return true;
    final last = shown.last;
    final options = ((last['payload'] as Map?)?['options'] as List?) ?? const [];
    return last['from_admin'] == true &&
        options.isNotEmpty &&
        options.every((o) => o is Map && ('${o['key']}'.startsWith('topic:') || o['key'] == 'other'));
  }

  /// Screens to open, so the fix is one tap away.
  Widget _actions(List<Map<String, dynamic>> actions) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final a in actions)
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '${a['route']}'),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text('${a['label']}'),
            ),
        ],
      ),
    );
  }

  Widget _typing() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            SizedBox(width: 8),
            Text(
              'KAYA Assistant is typing...',
              style: TextStyle(fontSize: 12.5, color: AppColors.neutral500),
            ),
          ],
        ),
      ),
    );
  }

  /// Answers already reported from this screen.
  final Set<int> _reported = {};

  Widget _feedbackButton(int id) {
    final done = _reported.contains(id);
    return IconButton(
      tooltip: done ? 'Reported' : 'Report This Answer',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
      iconSize: 15,
      icon: Icon(done ? Icons.flag : Icons.flag_outlined, color: AppColors.neutral400),
      onPressed: done ? null : () => _reportAnswer(id),
    );
  }

  Future<void> _reportAnswer(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Report This Answer?'),
        content: const Text('The KAYA team will read this answer and your question.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      final res = await _api.post('/support/feedback', data: {'message_id': id});
      if (!mounted) return;
      setState(() => _reported.add(id));
      AppToast.success(context, '${res.data['message'] ?? 'Thanks.'}');
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Widget _bubble(Map<String, dynamic> message) {
    final fromKaya = message['from_admin'] == true;
    final who = (message['from'] ?? 'KAYA').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            fromKaya ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: fromKaya ? Colors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              border: fromKaya
                  ? Border.all(color: AppColors.neutral200)
                  : null,
            ),
            child: _typedIds.contains(message['id'])
                ? _TypedText(
                    key: ValueKey('typed-${message['id']}'),
                    text: (message['body'] ?? '').toString(),
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: AppColors.neutral800),
                    onTick: _toBottom,
                    onDone: () => _typedIds.remove(message['id']),
                  )
                : Text(
                    (message['body'] ?? '').toString(),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: fromKaya ? AppColors.neutral800 : Colors.white,
                    ),
                  ),
          ),
          if (fromKaya) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  who,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500),
                ),
                // A wrong or odd answer goes to the team.
                if (message['from_assistant'] == true && message['id'] is int)
                  _feedbackButton(message['id'] as int),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// An answer written out word by word.
class _TypedText extends StatefulWidget {
  const _TypedText({
    super.key,
    required this.text,
    required this.style,
    required this.onTick,
    required this.onDone,
  });

  final String text;
  final TextStyle style;
  final VoidCallback onTick;
  final VoidCallback onDone;

  @override
  State<_TypedText> createState() => _TypedTextState();
}

class _TypedTextState extends State<_TypedText> {
  late final List<String> _words =
      RegExp(r'\S+\s*').allMatches(widget.text).map((m) => m.group(0)!).toList();
  Timer? _timer;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    // A long answer types a little faster, so none takes much over six seconds.
    final step = (_words.length / 160).ceil().clamp(1, 4);
    _timer = Timer.periodic(const Duration(milliseconds: 38), (t) {
      if (!mounted) return;
      setState(() => _shown = (_shown + step).clamp(0, _words.length));
      widget.onTick();
      if (_shown >= _words.length) {
        t.cancel();
        widget.onDone();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_words.take(_shown).join(), style: widget.style);
  }
}

/// Something's Broken: where it happened, what happened, a few words and an
/// optional screenshot. The app version and the phone go with it.
class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  static const _issues = {
    'app_closed': 'The app closed by itself',
    'button': 'A button does nothing',
    'wrong_info': 'Wrong information is shown',
    'cant_sign_in': 'I cannot sign in',
    'something_else': 'Something else',
  };
  static const _screens = {
    'home': 'Home', 'jobs': 'Jobs', 'chat': 'Chat',
    'wallet': 'Wallet', 'profile': 'Profile', 'other': 'Other',
  };

  final _details = TextEditingController();
  String _issue = 'button';
  String _screen = 'home';
  XFile? _shot;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked != null && mounted) setState(() => _shot = picked);
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final form = FormData.fromMap({
        'issue': _issue,
        'screen': _screen,
        'details': _details.text.trim(),
        'app_version': AppVersion.current,
        'device': '${Platform.operatingSystem} ${Platform.operatingSystemVersion}'.trim(),
        if (_shot != null) 'screenshot': await MultipartFile.fromFile(_shot!.path, filename: 'screenshot.jpg'),
      });
      final res = await ApiClient().post('/support/bug', data: form);
      if (!mounted) return;
      Navigator.pop(context, (res.data['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static const _label = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.neutral700);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 4),
          child: Row(
            children: [
              const Expanded(
                child: Text("Something's Broken",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.neutral900)),
              ),
              IconButton(
                onPressed: _sending ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('What Happened?', style: _label),
                const SizedBox(height: 8),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Column(
                    children: [
                      for (final (i, e) in _issues.entries.indexed) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.neutral200),
                        InkWell(
                          onTap: () => setState(() => _issue = e.key),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(e.value,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: _issue == e.key ? FontWeight.w600 : FontWeight.w400,
                                        color: _issue == e.key ? AppColors.primary : AppColors.neutral800,
                                      )),
                                ),
                                Icon(
                                  _issue == e.key ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: _issue == e.key ? AppColors.primary : AppColors.neutral400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Where?', style: _label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in _screens.entries)
                      ChoiceChip(
                        label: Text(e.value),
                        selected: _screen == e.key,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _screen = e.key),
                        selectedColor: AppColors.primary.withValues(alpha: 0.1),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: _screen == e.key ? AppColors.primary : AppColors.neutral300),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _screen == e.key ? AppColors.primary : AppColors.neutral700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Tell Us More', style: _label),
                const SizedBox(height: 8),
                TextField(
                  controller: _details,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'What were you doing when it happened? (optional)',
                    hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.neutral400),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.neutral300),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Screenshot', style: _label),
                const SizedBox(height: 8),
                _shot == null
                    ? OutlinedButton.icon(
                        onPressed: _sending ? null : _pick,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                        label: const Text('Add a Screenshot (optional)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.neutral700,
                          side: const BorderSide(color: AppColors.neutral300),
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(File(_shot!.path), width: 64, height: 64, fit: BoxFit.cover),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Screenshot added',
                                style: TextStyle(fontSize: 13.5, color: AppColors.neutral700)),
                          ),
                          TextButton(
                            onPressed: _sending ? null : () => setState(() => _shot = null),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                const SizedBox(height: 10),
                const Text(
                  'Your app version and phone model are sent with this.',
                  style: TextStyle(fontSize: 12, color: AppColors.neutral500),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_sending ? 'Sending...' : 'Send Report',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
