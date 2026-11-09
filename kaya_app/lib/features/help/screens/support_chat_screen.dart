import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_toast.dart';
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

    KAYA Assistant answers first, from KAYA's help and the person's own
    account, a few seconds after a message is sent; its answer arrives on the
    next poll like any other line. Talk to a Person hands the thread to the
    team, and the bar above the box always says which of the two is answering.
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
  bool _asking = false;

  /// The quick questions the server offers, as {key, label}.
  List<Map<String, dynamic>> _quick = const [];

  /// What a chat with the team can be about, as {key, label}.
  List<Map<String, dynamic>> _topics = const [];

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
    _topics = ((state['topics'] as List?) ?? const [])
        .whereType<Map>()
        .map((q) => q.cast<String, dynamic>())
        .toList();
    _quick = ((state['quick'] as List?) ?? const [])
        .whereType<Map>()
        .map((q) => q.cast<String, dynamic>())
        .toList();
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

  /// What it is about, so the right person on the team picks it up.
  Future<String?> _pickTopic() {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('What Is It About?'),
        children: [
          for (final t in _topics)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, '${t['key']}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('${t['label']}', style: const TextStyle(fontSize: 15)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _talkToPerson() async {
    if (_handingOff) return;

    String? topic;
    if (_topics.isNotEmpty) {
      topic = await _pickTopic();
      if (topic == null || !mounted) return;
    }

    setState(() => _handingOff = true);

    try {
      final res = await _api.post('/support/person', data: {'topic': ?topic});
      final data = res.data['data'] as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>?;

      if (!mounted) return;

      setState(() {
        if (message != null) _messages = _merged([message]);
        _readAssistant(data['assistant'] as Map<String, dynamic>?);
        _awaitingSince = null;
        _handingOff = false;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _handingOff = false);
      AppToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
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

  /// A quick question: asked and answered at once, no waiting.
  Future<void> _askQuick(String key) async {
    if (_asking) return;
    setState(() => _asking = true);

    try {
      final res = await _api.post('/support/quick', data: {'key': key});
      final data = res.data['data'] as Map<String, dynamic>;
      final pair = ((data['messages'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();

      if (!mounted) return;

      setState(() {
        _typeOut(pair);
        _messages = _merged(pair);
        _readAssistant(data['assistant'] as Map<String, dynamic>?);
        _asking = false;
      });
      _toBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() => _asking = false);
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
                _withPerson ? 'The KAYA team will reply' : 'KAYA Assistant is answering',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.neutral500),
              ),
          ],
        ),
        actions: [
          if (_assistantOn)
            TextButton(
              onPressed: _handingOff
                  ? null
                  : (_withPerson ? _backToAssistant : _talkToPerson),
              child: Text(_withPerson ? 'Back to Assistant' : 'Talk to a Person'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_assistantOn && !_withPerson && _quick.isNotEmpty && !_assistantTyping)
            _quickRow(),
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
      final assistant = _assistantOn && !_withPerson;

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.support_agent_outlined,
                  size: 48, color: AppColors.neutral300),
              const SizedBox(height: 14),
              const Text(
                'Tell Us What Happened',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral700),
              ),
              const SizedBox(height: 6),
              Text(
                assistant
                    ? 'KAYA Assistant answers right away from the KAYA help. '
                        'This chat clears when you leave it.'
                    : 'Somebody at KAYA reads this and answers here. '
                        'Say which account, job or payment it is about.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.neutral500),
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
      itemBuilder: (context, i) =>
          i < _messages.length ? _bubble(_messages[i]) : _typing(),
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

  /// The quick questions, one tap each, like a shop's help chat.
  Widget _quickRow() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final q in _quick)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: OutlinedButton(
                  onPressed: _asking ? null : () => _askQuick('${q['key']}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.neutral300),
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                  ),
                  child: Text('${q['label']}'),
                ),
              ),
          ],
        ),
      ),
    );
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
