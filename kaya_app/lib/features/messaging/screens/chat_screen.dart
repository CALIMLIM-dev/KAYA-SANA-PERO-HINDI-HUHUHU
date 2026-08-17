import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/messaging_provider.dart';
import '../../../core/widgets/app_toast.dart';
import '../widgets/job_tracking_panel.dart';
import '../../moderation/widgets/report_sheet.dart';

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

class _ChatScreenState extends State<ChatScreen> {
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

    if (_conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MessagingProvider>().fetchMessages(_conversationId!);
        }
      });
    }
  }

  @override
  void dispose() {
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

    unawaited(() async {
      final messaging = context.read<MessagingProvider>();
      final success = await messaging.sendMessage(_conversationId!, text);

      if (!mounted) return;

      if (success) {
        _scrollToBottom();
        return;
      }

      // Give the words back rather than swallowing them.
      if (_controller.text.isEmpty) _controller.text = text;
      AppToast.error(
          context, messaging.messagesErrorMessage ?? 'Failed to send message');
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
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final name        = args?['name']        as String? ?? 'User';
    final jobTitle    = args?['jobTitle']    as String?;
    final jobId       = args?['jobId']       as int?;
    final otherUserId = args?['otherUserId'] as int?;
    final isVerified  = args?['isVerified']  as bool? ?? false;
    final otherRole   = args?['otherRole']   as String? ?? 'worker';

    // Location sharing: only on a hire that is actually in progress, and the
    // panel shows a different face to each party.
    final applicationId = args?['applicationId'] as int?;
    final jobStatus     = args?['jobStatus']     as String?;
    final iAmWorker     = (args?['myRole'] as String?) == 'worker';
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
          otherUserId, args?['lastSeenAt'] as String?),
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
            }
          },
          // "View Job Details" used to live here as well as on the visible
          // button in the job card below. Two ways to reach the same screen
          // from one bar reads as a bug, and the button is the discoverable
          // one — so the menu keeps only what has nowhere else to go.
          itemBuilder: (_) => [
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
                color: AppColors.primary,
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
              if (showTime) ...[
                Text(_formatTime((msg['created_at'] ?? '').toString()),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.neutral400)),
                const SizedBox(width: 3),
              ],
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
