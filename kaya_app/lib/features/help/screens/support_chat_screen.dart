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
    Ten seconds rather than the chat's eight: an answer here comes from a
    person reading a queue, not from somebody typing back.
*/
class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key, this.seed});

  /// Messages in place of the fetch, for a render test.
  final List<Map<String, dynamic>>? seed;

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const Duration _pollEvery = Duration(seconds: 10);

  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();

    final seed = widget.seed;

    if (seed != null) {
      _messages = seed;
      _loading = false;

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

  Future<void> _load({bool quiet = false}) async {
    if (await ApiClient.getToken() == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final res = await _api.get('/support');
      final data = res.data['data'] as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _messages = ((data['messages'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
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
        _messages = [..._messages, message];
        _sending = false;
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent_outlined,
                  size: 48, color: AppColors.neutral300),
              SizedBox(height: 14),
              Text(
                'Tell us what happened',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral700),
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
      itemCount: _messages.length,
      itemBuilder: (context, i) => _bubble(_messages[i]),
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
