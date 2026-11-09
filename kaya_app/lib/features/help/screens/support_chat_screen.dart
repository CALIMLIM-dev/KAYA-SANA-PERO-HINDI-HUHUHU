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
        _messages = incremental ? _merged(incoming) : incoming;
        _loading = false;
        _error = null;
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

  Future<void> _talkToPerson() async {
    if (_handingOff) return;
    setState(() => _handingOff = true);

    try {
      final res = await _api.post('/support/person');
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
        title: const Text('Message KAYA',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Expanded(child: _body()),
          if (_assistantOn) _assistantBar(),
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
                        'Tap Talk to a Person to reach the team. '
                        'Say which account, job or payment it is about.'
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

  /// Who is answering, and the way to reach a person.
  Widget _assistantBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: const BoxDecoration(
        color: AppColors.neutral50,
        border: Border(top: BorderSide(color: AppColors.neutral200)),
      ),
      child: _withPerson
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'A KAYA team member will reply here.',
                style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
              ),
            )
          : Row(
              children: [
                const Expanded(
                  child: Text(
                    'KAYA Assistant answers first.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.neutral600),
                  ),
                ),
                TextButton(
                  onPressed: _handingOff ? null : _talkToPerson,
                  child: const Text('Talk to a Person'),
                ),
              ],
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
            child: Text(
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
            Text(
              who,
              style: const TextStyle(fontSize: 11.5, color: AppColors.neutral500),
            ),
          ],
        ],
      ),
    );
  }
}
