import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/messaging_provider.dart';

/// Chat Screen — message thread for a real conversation.
/// Arguments: { conversationId, name, jobTitle, jobId, otherUserId,
///              isVerified, otherRole ('employer'|'worker') }
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _jobCardExpanded = false;
  bool _sending = false;

  int? _conversationId;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _conversationId = args is Map ? args['conversationId'] as int? : null;

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _conversationId == null || _sending) return;

    setState(() => _sending = true);
    _controller.clear();

    final success =
        await context.read<MessagingProvider>().sendMessage(_conversationId!, text);

    if (!mounted) return;
    setState(() => _sending = false);

    if (success) {
      _scrollToBottom();
    } else {
      final error = context.read<MessagingProvider>().messagesErrorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error ?? 'Failed to send message'),
            backgroundColor: AppColors.error),
      );
    }
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

    if (_conversationId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('No conversation specified.')),
      );
    }

    final myId = context.watch<AuthProvider>().user?['id'] as int?;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(context, name, isVerified, otherRole, jobId, otherUserId),
      body: Column(
        children: [
          if (jobTitle != null)
            _buildJobCard(jobTitle, jobId, context),

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

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = (msg['sender_id'] as int?) == myId;
                    return isMine ? _sentBubble(msg) : _receivedBubble(msg);
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
      bool isVerified, String otherRole, int? jobId, int? otherUserId) {
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
              child: Row(
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
                    const Icon(Icons.verified, size: 14, color: AppColors.success),
                  ],
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
              case 'job':
                if (jobId != null) {
                  Navigator.pushNamed(context, '/job-details',
                      arguments: {'jobId': jobId});
                }
                break;
              case 'report':
                _showReportDialog(context);
                break;
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'job',
              enabled: jobId != null,
              child: const Row(
                children: [
                  Icon(Icons.work_outline, size: 18, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('View Job Details'),
                ],
              ),
            ),
            const PopupMenuDivider(),
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
                          fontSize: 13,
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
                        const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── message bubbles ──────────────────────────────────────────────────────────

  Widget _receivedBubble(Map<String, dynamic> msg) {
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                const SizedBox(height: 3),
                Text(_formatTime((msg['created_at'] ?? '').toString()),
                    style: const TextStyle(fontSize: 11, color: AppColors.neutral400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentBubble(Map<String, dynamic> msg) {
    final isRead = (msg['is_read'] as bool?) ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
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
                style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.4)),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_formatTime((msg['created_at'] ?? '').toString()),
                  style: const TextStyle(fontSize: 11, color: AppColors.neutral400)),
              const SizedBox(width: 3),
              Icon(
                isRead ? Icons.done_all : Icons.done,
                size: 13,
                color: isRead ? AppColors.primary : AppColors.neutral400,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report User'),
        content: const Text(
            'Are you sure you want to report this user? Our team will review the conversation.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Report submitted. Thank you.'),
                    backgroundColor: AppColors.neutral600),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Report', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
