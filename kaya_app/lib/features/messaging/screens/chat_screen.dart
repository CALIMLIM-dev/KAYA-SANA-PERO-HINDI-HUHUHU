import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/services/realtime_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../widgets/job_tracking_panel.dart';
import '../../moderation/widgets/report_sheet.dart';
import '../../invitations/widgets/invite_to_job.dart';
import '../../../providers/app_mode_provider.dart';

/// Chat Screen — message thread for a real conversation.
/// Arguments: { conversationId, name, jobTitle, jobId, otherUserId,
///              isVerified, otherRole ('employer'|'worker') }
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

/// Whether the other person is around, from their last authenticated request.
///
/// Not a presence channel. Presence is the textbook answer, but REVERB_HOST is
/// a LAN address, so anyone testing off that network would show as permanently
/// offline — and a user who is online appearing offline is worse than no
/// indicator at all. A timestamp works over plain HTTP and degrades to "active
/// 2h ago" instead of to a lie.
///
/// Two minutes rather than seconds: the app touches this at most once a minute,
/// so a tighter window would blink someone offline while they are typing.
class _Activity {
  const _Activity(this.isActive, this.label);

  final bool isActive;
  final String label;

  static _Activity? from(String? lastSeenAt) {
    if (lastSeenAt == null) return null;

    final seen = DateTime.tryParse(lastSeenAt)?.toLocal();
    if (seen == null) return null;

    final ago = DateTime.now().difference(seen);

    if (ago.inMinutes < 2) return const _Activity(true, 'Active now');
    if (ago.inMinutes < 60) return _Activity(false, 'Active ${ago.inMinutes}m ago');
    if (ago.inHours < 24) return _Activity(false, 'Active ${ago.inHours}h ago');
    // Beyond a day, say nothing. "Active 23 days ago" is not information the
    // person messaging them can use, and it reads as a judgement.
    return null;
  }
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  MessagingProvider? _messaging;
  bool _jobCardExpanded = false;
  /*
      Which older message has had its time revealed.

      A timestamp under every bubble triples the vertical space a conversation
      takes and repeats a number nobody is reading — in a burst of five messages
      sent in the same minute it is the same value five times.

      So: the newest message always shows its time, because "when was the last
      thing said" is the one people genuinely want. Any older bubble reveals its
      own on tap. One at a time — tapping another moves the reveal rather than
      accumulating, so the thread never drifts back to the wall of times this
      replaced.
  */
  int? _revealedTimeFor;

  int? _conversationId;
  bool _requested = false;

  /*
      The thread's own details, when the caller did not supply them.

      Opening a chat from the inbox hands over the name, the job, the other
      person's id and the hire — the row on screen already knew all of it. A
      notification knows only which conversation the message landed in, so
      everything else arrived null and the screen fell back to the word User,
      no job card, a dead View Profile button and a Report that could not name
      anyone.

      Rather than making every caller pass nine fields, the screen now looks up
      what it was not told. Any future entry point can push a bare
      conversationId and get a complete chat.
  */
  Map<String, dynamic>? _resolved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _conversationId = args is Map ? args['conversationId'] as int? : null;

    // Held so dispose() can unsubscribe — by then the element is detached and
    // context lookups throw.
    _messaging = context.read<MessagingProvider>();

    // So an optimistic message knows which side of the thread it belongs on
    // before the server has confirmed it exists.
    _messaging?.selfId = context.read<AuthProvider>().user?['id'] as int?;

    // Only the name is checked: the inbox always sends it, and a notification
    // never does, so it tells the two callers apart without guessing.
    final needsDetails = args is! Map || args['name'] == null;

    if (_conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MessagingProvider>().fetchMessages(_conversationId!);
          if (needsDetails) _resolveDetails();
        }
      });
      WidgetsBinding.instance.addObserver(this);
      _startPolling();
      RealtimeService.instance.connected.addListener(_onSocketChanged);
    }
  }

  /// Polling stops while the app is off-screen and catches up on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;

    if (_foreground && mounted && _conversationId != null) {
      // Straight away rather than waiting for the next tick: coming back to a
      // chat is exactly when someone wants to see what they missed.
      _markActive();
      _messaging?.fetchMessages(_conversationId!, silent: true);
    }
  }

  /*
      Polling is how messages arrive.

      Not a fallback any more — the contract. A socket, when one happens to be
      connected, just makes the same thread update sooner; nothing depends on
      it being there, which is what makes this work identically on WiFi, on
      mobile data and on a connection that keeps dropping.

      The interval adapts, for two reasons that pull the same way. A live
      conversation deserves a fast poll; a thread nobody has typed in for ten
      minutes does not, and neither does the battery. And the API is limited to
      60 requests a minute per token — a flat three-second poll is 20 of them
      before the badge, the feed or anything else has asked for anything, so a
      chat left open would start collecting 429s and look broken.

      Each poll asks only for messages after the newest one already held, which
      is a ~50 byte answer when nothing has changed.
  */
  static const Duration _activePoll = Duration(seconds: 3);
  static const Duration _idlePoll = Duration(seconds: 12);

  /// How long a thread stays "active" after the last message either way.
  static const Duration _activeWindow = Duration(minutes: 2);

  Timer? _pollTimer;
  DateTime _lastActivity = DateTime.now();
  bool _foreground = true;

  /// Fills in what the caller left out, from the conversation list.
  ///
  /// Fetches the list only when it is not already loaded — coming from the
  /// inbox it always is, and refetching would cost a request to learn what the
  /// screen was just handed.
  Future<void> _resolveDetails() async {
    final messaging = context.read<MessagingProvider>();

    if (messaging.conversations.isEmpty) {
      await messaging.fetchConversations(silent: true);
    }
    if (!mounted) return;

    Map<String, dynamic>? conv;
    for (final c in messaging.conversations) {
      if (c['id'] == _conversationId) {
        conv = c;
        break;
      }
    }
    if (conv == null || !mounted) return;

    final myId = context.read<AuthProvider>().user?['id'] as int?;
    final iAmWorker = conv['worker_id'] == myId;
    final other = (iAmWorker ? conv['employer'] : conv['worker']) as Map<String, dynamic>?;
    final job = conv['job'] as Map<String, dynamic>?;

    setState(() {
      _resolved = {
        'name': other?['name'] ?? (iAmWorker ? 'Employer' : 'Worker'),
        'jobTitle': job?['title'],
        'jobId': conv?['job_id'],
        'otherUserId': other?['id'],
        'isVerified': (other?['is_verified'] as bool?) ?? false,
        'lastSeenAt': other?['last_seen_at'],
        'applicationId': conv?['application_id'],
        'jobStatus': job?['status'],
        'myRole': iAmWorker ? 'worker' : 'employer',
        'otherRole': iAmWorker ? 'employer' : 'worker',
      };
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _conversationId == null) return;

      // Nothing polls while the app is off-screen. The thread refreshes on
      // resume, and the alternative is spending someone's data in their pocket.
      if (!_foreground) return;

      final since = DateTime.now().difference(_lastPoll);
      final interval =
          DateTime.now().difference(_lastActivity) < _activeWindow
              ? _activePoll
              : _idlePoll;

      if (since < interval) return;

      _lastPoll = DateTime.now();
      _messaging?.fetchMessages(_conversationId!, silent: true);
    });
  }

  DateTime _lastPoll = DateTime.fromMillisecondsSinceEpoch(0);

  /// Called whenever a message is sent or arrives, to keep the fast interval.
  void _markActive() => _lastActivity = DateTime.now();

  /// One catch-up read the moment the socket comes back, for anything that was
  /// sent while it was away.
  void _onSocketChanged() {
    if (!mounted || _conversationId == null) return;
    if (!RealtimeService.instance.connected.value) return;

    _messaging?.fetchMessages(_conversationId!, silent: true);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    RealtimeService.instance.connected.removeListener(_onSocketChanged);
    // Releases the socket subscription for this thread. Read before super, and
    // via the stored provider rather than `context.read`, because the element
    // is already detached by the time dispose runs.
    _messaging?.leaveThread();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /*
      Send without blocking the composer.

      The button used to disable itself and spin until the round trip finished.
      On a tunnel that is most of a second, during which you could not type the
      next line — and chat is the one place people fire several short messages
      in a row. No messaging app does this, for that reason.

      The input clears immediately and the request goes off unawaited. The
      message appears when the server answers, which is the same moment it did
      before; the difference is that the keyboard stays live in the meantime.
      A failure still surfaces as a toast, and the text is put back so it is not
      lost.
  */
  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null) return;

    _controller.clear();

    /*
        The message is already on screen by the time this returns.

        sendMessage adds it optimistically and marks it pending, so there is
        nothing to wait for before scrolling to it. A failure is shown on the
        message itself — greyed, with a retry — rather than as a toast plus the
        text shoved back into the input box, which lost the reading order and
        made it unclear whether anything had been sent at all.
    */
    // Someone is typing, so keep the thread on the fast poll.
    _markActive();

    unawaited(() async {
      final messaging = context.read<MessagingProvider>();
      _scrollToBottom();

      await messaging.sendMessage(_conversationId!, text);

      if (mounted) _scrollToBottom();
    }());
  }

  String _formatTime(String isoDate) {
    final dt = DateTime.tryParse(isoDate)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    /*
        What the caller passed, then what the screen looked up itself.

        The inbox supplies everything and _resolved stays null. A notification
        supplies only the conversation id, and every field below used to fall
        through to a placeholder — the header read User, the job card vanished,
        View Profile did nothing and Report had no one to report. The thread was
        the one part that worked, which made it look like a rendering bug rather
        than a screen missing three quarters of its input.
    */
    final args = <String, dynamic>{...?_resolved, ...?routeArgs};

    final name        = args['name']        as String? ?? 'User';
    final jobTitle    = args['jobTitle']    as String?;
    final jobId       = args['jobId']       as int?;
    final otherUserId = args['otherUserId'] as int?;
    final isVerified  = args['isVerified']  as bool? ?? false;
    final otherRole   = args['otherRole']   as String? ?? 'worker';

    // Location sharing: only on a hire that is actually in progress, and the
    // panel shows a different face to each party.
    final applicationId = args['applicationId'] as int?;
    final jobStatus     = args['jobStatus']     as String?;
    final iAmWorker     = (args['myRole'] as String?) == 'worker';
    final canTrack      = applicationId != null && jobStatus == 'in_progress';

    if (_conversationId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('No conversation specified.')),
      );
    }

    final myId = context.watch<AuthProvider>().user?['id'] as int?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(context, name, isVerified, otherRole, jobId,
          otherUserId, args['lastSeenAt'] as String?),
      body: Column(
        children: [
          if (jobTitle != null)
            _buildJobCard(jobTitle, jobId, context),

          if (canTrack)
            JobTrackingPanel(
              applicationId: applicationId,
              isWorker: iAmWorker,
              otherPartyName: name.split(' ').first,
            ),

          Expanded(
            child: Consumer<MessagingProvider>(
              builder: (context, provider, _) {
                if (provider.isMessagesLoading && provider.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.messagesErrorMessage != null && provider.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 48, color: AppColors.neutral400),
                          const SizedBox(height: 12),
                          Text(provider.messagesErrorMessage!,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => context
                                .read<MessagingProvider>()
                                .fetchMessages(_conversationId!),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final messages = provider.messages;
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet — say hello!',
                        style: TextStyle(color: AppColors.neutral500)),
                  );
                }

                _scrollToBottom();

                /*
                    "Seen" goes under the LAST message of yours they have read,
                    and nowhere else.

                    Messenger does this, and the reason is that reading is
                    cumulative: if they have seen your newest message they have
                    seen every earlier one, so a label on each is the same fact
                    repeated down the whole thread. One label at the furthest
                    point their eyes reached says it once, in the place that
                    answers the actual question — "did they see it?"
                */
                var seenAt = -1;
                for (var i = messages.length - 1; i >= 0; i--) {
                  final m = messages[i];
                  if ((m['sender_id'] as int?) != myId) continue;
                  if (m['is_read'] == true) seenAt = i;
                  break;
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = (msg['sender_id'] as int?) == myId;
                    final id = msg['id'] as int?;

                    // Newest always; older ones only while tapped.
                    final showTime =
                        i == messages.length - 1 || _revealedTimeFor == id;

                    void toggleTime() => setState(() =>
                        _revealedTimeFor = _revealedTimeFor == id ? null : id);

                    return isMine
                        ? _sentBubble(msg,
                            showSeen: i == seenAt,
                            showTime: showTime,
                            onTap: toggleTime)
                        : _receivedBubble(msg,
                            showTime: showTime, onTap: toggleTime);
                  },
                );
              },
            ),
          ),

          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── app bar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, String name,
      bool isVerified, String otherRole, int? jobId, int? otherUserId,
      String? lastSeenAt) {
    final activity = _Activity.from(lastSeenAt);

    void openProfile() {
      if (otherUserId == null) return;
      Navigator.pushNamed(
        context,
        otherRole == 'worker' ? '/worker-profile' : '/employer-profile',
        arguments: otherRole == 'worker'
            ? {'workerId': otherUserId}
            : {'employerId': otherUserId},
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.neutral900,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: openProfile,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.neutral900),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified,
                            size: 14, color: AppColors.success),
                      ],
                    ],
                  ),
                  if (activity != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (activity.isActive) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          activity.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: activity.isActive
                                ? AppColors.success
                                : AppColors.neutral500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: AppColors.neutral600),
          tooltip: 'View Profile',
          onPressed: otherUserId == null ? null : openProfile,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.neutral600),
          onSelected: (val) {
            switch (val) {
              case 'report':
                _showReportDialog(context, otherUserId, name);
                break;
              case 'invite':
                if (otherUserId != null) {
                  showInviteToJobSheet(context,
                      workerId: otherUserId, workerName: name);
                }
                break;
            }
          },
          // "View Job Details" used to live here as well as on the visible
          // button in the job card below. Two ways to reach the same screen
          // from one bar reads as a bug, and the button is the discoverable
          // one — so the menu keeps only what has nowhere else to go.
          itemBuilder: (_) => [
            /*
                Hiring someone you already know, without leaving the chat.

                Every person you have ever hired has a thread here, so this is
                already the list of people you would rehire — walking out to
                Search and back into their profile to reach the same dialog was
                the whole reason a repeat hire felt slower than a first one.

                Only shown to an account that can actually post work. A worker
                with no employer profile has nothing to invite anyone to.
            */
            if (context.read<AppModeProvider>().hasEmployerProfile)
              const PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.work_outline, size: 18, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('Invite to another job'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Report User', style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── job card ─────────────────────────────────────────────────────────────────

  Widget _buildJobCard(String jobTitle, int? jobId, BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _jobCardExpanded = !_jobCardExpanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.neutral200, width: 1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.work_outline,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(jobTitle,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.neutral900),
                      overflow: TextOverflow.ellipsis),
                ),
                Icon(
                  _jobCardExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.neutral400,
                ),
              ],
            ),
            if (_jobCardExpanded && jobId != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pushNamed(context, '/job-details',
                      arguments: {'jobId': jobId}),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle:
                        const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('View Full Job Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── input bar ────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: AppColors.neutral400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Always live. The spinner that used to replace this icon meant you
            // could not send a second message until the first came back.
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── message bubbles ──────────────────────────────────────────────────────────

  Widget _receivedBubble(
    Map<String, dynamic> msg, {
    bool showTime = false,
    VoidCallback? onTap,
  }) {
    final senderName = ((msg['sender'] as Map?)?['name'] ?? '?').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 6, bottom: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16),
                        topLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text((msg['message_text'] ?? '').toString(),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.neutral900, height: 1.4)),
                  ),
                ),
                if (showTime) ...[
                  const SizedBox(height: 3),
                  Text(_formatTime((msg['created_at'] ?? '').toString()),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.neutral400)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentBubble(
    Map<String, dynamic> msg, {
    bool showSeen = false,
    bool showTime = false,
    VoidCallback? onTap,
  }) {
    final isRead = (msg['is_read'] as bool?) ?? false;
    final readAt = (msg['read_at'] ?? '').toString();

    // Optimistic state. 'pending' is still in flight, 'failed' did not land.
    final status = (msg['status'] ?? 'sent').toString();
    final isPending = status == 'pending';
    final isFailed = status == 'failed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                // Faded while in flight, so "sending" is legible at a glance
                // without a spinner sitting in the middle of the conversation.
                color: isFailed
                    ? AppColors.neutral400
                    : isPending
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text((msg['message_text'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize: 14, color: Colors.white, height: 1.4)),
            ),
          ),

          /*
              The tick stays on every message; only the time hides.

              Sent-versus-seen is the state of that individual message and has
              to be visible without asking — it is the reason to glance at the
              thread at all. The clock beside it is the part that repeats.
          */
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showTime && !isPending && !isFailed) ...[
                Text(_formatTime((msg['created_at'] ?? '').toString()),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.neutral400)),
                const SizedBox(width: 3),
              ],
              /*
                  Three states, not two.

                  A clock icon while sending, a tick once the server has it,
                  and a tap-to-retry when it did not land. The failed case
                  matters most: without it an optimistic message is a lie —
                  it looks delivered and never was.
              */
              if (isPending)
                const Icon(Icons.schedule, size: 13, color: AppColors.neutral400)
              else if (isFailed)
                GestureDetector(
                  onTap: () {
                    final id = msg['id'] as int?;
                    if (id == null || _conversationId == null) return;
                    _messaging?.retryMessage(_conversationId!, id);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 13, color: AppColors.error),
                      SizedBox(width: 3),
                      Text('Not sent. Tap to retry',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error)),
                    ],
                  ),
                )
              else
                Icon(
                  isRead ? Icons.done_all : Icons.done,
                  size: 13,
                  color: isRead ? AppColors.primary : AppColors.neutral400,
                ),
            ],
          ),

          // The label, only on the furthest message they have read.
          //
          // The tick alone was too quiet to answer "did they see it?" — the
          // question people actually open the chat to check. With the time when
          // there is one, because "Seen 3:42 PM" tells you whether they read it
          // before or after you sent the next thing.
          if (showSeen) ...[
            const SizedBox(height: 2),
            Text(
              readAt.isEmpty ? 'Seen' : 'Seen ${_formatTime(readAt)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Opens the real report sheet.
  ///
  /// What stood here was an "are you sure?" dialog that popped a
  /// "Report submitted. Thank you." toast and sent nothing. Someone reporting
  /// harassment was told it had been received while no report existed, which is
  /// worse than having no button — it stops them telling anyone who could act.
  void _showReportDialog(BuildContext context, int? otherUserId, String name) {
    if (otherUserId == null) {
      AppToast.info(context, 'This conversation has no one to report.');
      return;
    }

    ReportSheet.show(
      context,
      reportedId: otherUserId,
      reportedName: name,
      subjectType: 'message',
    );
  }
}
