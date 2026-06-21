import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Chat Screen — message thread between employer and worker
/// Arguments: { conversationId, name, jobTitle, jobLocation, jobSalary,
///              isVerified, isOnline, otherRole ('employer'|'worker'),
///              jobStatus ('accepted'|'in_progress'|'completed') }
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _jobCardExpanded = false;
  bool _showQuickReplies = true;
  bool _showTrackingPanel = false;

  // Mock worker tracking status — TODO: replace with real GPS
  String _workerTrackingStatus = 'on_the_way'; // on_the_way | arrived | working | done

  // TODO: Replace with MessagingProvider
  final List<Map<String, dynamic>> _messages = [
    {
      'id': 1,
      'text': 'Hi! I saw your application for the job.',
      'isMine': false,
      'time': '10:30 AM',
      'isRead': true,
    },
    {
      'id': 2,
      'text': 'Your profile looks great! When can you start?',
      'isMine': false,
      'time': '10:31 AM',
      'isRead': true,
    },
    {
      'id': 3,
      'text': 'Hello! Thank you for considering my application.',
      'isMine': true,
      'time': '10:35 AM',
      'isRead': true,
    },
    {
      'id': 4,
      'text': "I'm available this week. What time works best?",
      'isMine': true,
      'time': '10:35 AM',
      'isRead': true,
    },
    {
      'id': 5,
      'text': 'How about tomorrow at 2 PM?',
      'isMine': false,
      'time': '10:40 AM',
      'isRead': true,
    },
    {
      'id': 6,
      'text': "Perfect! I'll be there. Looking forward to it! 😊",
      'isMine': true,
      'time': '10:42 AM',
      'isRead': false,
    },
  ];

  // Quick reply sets — different for worker vs employer
  final List<String> _workerQuickReplies = [
    'I\'m available 👍',
    'When do we start?',
    'What\'s the location?',
    'I\'m on my way',
    'Job is done ✅',
    'Can we reschedule?',
  ];

  final List<String> _employerQuickReplies = [
    'Great, you\'re hired! 🎉',
    'Can you start tomorrow?',
    'Please confirm your availability',
    'Job is completed ✅',
    'Payment sent 💸',
    'Thank you for the work!',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage([String? quickText]) {
    final text = quickText ?? _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({
        'id': _messages.length + 1,
        'text': text,
        'isMine': true,
        'time': _formatTime(DateTime.now()),
        'isRead': false,
      });
      if (quickText == null) _controller.clear();
      _showQuickReplies = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour == 0 ? 12 : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final name       = args?['name']        as String? ?? 'Employer';
    final jobTitle   = args?['jobTitle']    as String? ?? 'Emergency Pipe Repair';
    final jobLocation= args?['jobLocation'] as String? ?? 'Pangasinan';
    final jobSalary  = args?['jobSalary']   as String? ?? '₱1,200/day';
    final isVerified = args?['isVerified']  as bool?   ?? true;
    final isOnline   = args?['isOnline']    as bool?   ?? true;
    final otherRole  = args?['otherRole']   as String? ?? 'worker';
    final jobStatus  = args?['jobStatus']   as String? ?? 'in_progress';
    final quickReplies = otherRole == 'worker'
        ? _workerQuickReplies
        : _employerQuickReplies;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _buildAppBar(context, name, isVerified, isOnline, otherRole),
      body: Column(
        children: [
          // ── Job context card (collapsible) ──
          _buildJobCard(jobTitle, jobLocation, jobSalary, jobStatus, context),

          // ── Tracking panel (employer only, in_progress) ──
          if (_showTrackingPanel &&
              jobStatus == 'in_progress' &&
              otherRole == 'worker')
            _buildTrackingPanel(name),

          // ── Messages list ──
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              itemCount: _messages.length,
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final showDateDivider = i == 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDateDivider) _dateDivider('Today'),
                    (msg['isMine'] as bool)
                        ? _sentBubble(msg)
                        : _receivedBubble(msg),
                  ],
                );
              },
            ),
          ),

          // ── Quick replies ──
          if (_showQuickReplies)
            _buildQuickReplies(quickReplies),

          // ── Input bar ──
          _buildInputBar(),
        ],
      ),
    );
  }

  // ─── app bar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext context, String name,
      bool isVerified, bool isOnline, String otherRole) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.neutral900,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.neutral900),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () => otherRole == 'worker'
            ? Navigator.pushNamed(context, '/worker-profile')
            : Navigator.pushNamed(context, '/employer-profile'),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? AppColors.success
                            : AppColors.neutral400),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // View profile shortcut
        IconButton(
          icon: const Icon(Icons.person_outline, color: AppColors.neutral600),
          tooltip: 'View Profile',
          onPressed: () => otherRole == 'worker'
              ? Navigator.pushNamed(context, '/worker-profile')
              : Navigator.pushNamed(context, '/employer-profile'),
        ),
        // More options
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.neutral600),
          onSelected: (val) {
            switch (val) {
              case 'job':
                Navigator.pushNamed(context, '/job-details');
                break;
              case 'report':
                _showReportDialog(context);
                break;
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'job',
              child: Row(
                children: [
                  Icon(Icons.work_outline,
                      size: 18, color: AppColors.primary),
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
                  Icon(Icons.flag_outlined,
                      size: 18, color: AppColors.error),
                  SizedBox(width: 10),
                  Text('Report User',
                      style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─── job card ─────────────────────────────────────────────────────────────────

  Widget _buildJobCard(String jobTitle, String jobLocation,
      String jobSalary, String jobStatus, BuildContext context) {

    // Status chip config
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    switch (jobStatus) {
      case 'in_progress':
        statusColor = AppColors.warning;
        statusLabel = 'In Progress';
        statusIcon = Icons.construction;
        break;
      case 'completed':
        statusColor = AppColors.success;
        statusLabel = 'Completed';
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = AppColors.success;
        statusLabel = 'Accepted';
        statusIcon = Icons.handshake;
    }

    return GestureDetector(
      onTap: () => setState(() => _jobCardExpanded = !_jobCardExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: AppColors.neutral200, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Collapsed row
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(jobTitle,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900),
                          overflow: TextOverflow.ellipsis),
                      // Job status chip
                      Row(
                        children: [
                          Icon(statusIcon, size: 11, color: statusColor),
                          const SizedBox(width: 4),
                          Text(statusLabel,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                // Track button — only for in_progress
                if (jobStatus == 'in_progress') ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(
                        () => _showTrackingPanel = !_showTrackingPanel),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _showTrackingPanel
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on,
                              size: 13,
                              color: _showTrackingPanel
                                  ? Colors.white
                                  : AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Track',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _showTrackingPanel
                                      ? Colors.white
                                      : AppColors.primary)),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Icon(
                  _jobCardExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.neutral400,
                ),
              ],
            ),

            // Expanded details
            if (_jobCardExpanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _detailChip(Icons.location_on_outlined, jobLocation),
                  const SizedBox(width: 12),
                  _detailChip(Icons.payments_outlined, jobSalary,
                      color: AppColors.success),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/job-details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
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

  // ─── tracking panel ──────────────────────────────────────────────────────────

  Widget _buildTrackingPanel(String workerName) {
    final statuses = [
      {'key': 'on_the_way', 'label': 'On the Way', 'icon': Icons.directions_walk},
      {'key': 'arrived',    'label': 'Arrived',    'icon': Icons.place},
      {'key': 'working',    'label': 'Working',    'icon': Icons.construction},
      {'key': 'done',       'label': 'Done',       'icon': Icons.check_circle},
    ];

    final currentIdx = statuses.indexWhere((s) => s['key'] == _workerTrackingStatus);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.neutral200, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tracking $workerName',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.neutral900)),
                      const Text('Live location — updates every 30s',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.neutral400)),
                    ],
                  ),
                ),
                // Close
                GestureDetector(
                  onTap: () =>
                      setState(() => _showTrackingPanel = false),
                  child: const Icon(Icons.close,
                      size: 18, color: AppColors.neutral400),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Map placeholder
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.neutral200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neutral300),
            ),
            child: Stack(
              children: [
                // Map bg
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: const Color(0xFFE8F4E8),
                    child: Center(
                      child: Icon(Icons.map_outlined,
                          size: 48, color: AppColors.neutral400),
                    ),
                  ),
                ),
                // Worker pin
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(workerName.split(' ').first,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.location_pin,
                          color: AppColors.primary, size: 28),
                    ],
                  ),
                ),
                // Distance badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me,
                            size: 12, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text('1.2 km away',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Status progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: statuses.asMap().entries.map((entry) {
                final i = entry.key;
                final s = entry.value;
                final isDone = i < currentIdx;
                final isCurrent = i == currentIdx;

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _workerTrackingStatus =
                                  s['key'] as String),
                          child: Column(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isDone || isCurrent
                                      ? AppColors.primary
                                      : AppColors.neutral200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  s['icon'] as IconData,
                                  size: 16,
                                  color: isDone || isCurrent
                                      ? Colors.white
                                      : AppColors.neutral400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(s['label'] as String,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isCurrent
                                          ? FontWeight.w700
                                          : FontWeight.normal,
                                      color: isCurrent
                                          ? AppColors.primary
                                          : AppColors.neutral500),
                                  textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                      if (i < statuses.length - 1)
                        Expanded(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.only(bottom: 20),
                            color: i < currentIdx
                                ? AppColors.primary
                                : AppColors.neutral200,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String label,
      {Color color = AppColors.neutral600}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── quick replies ────────────────────────────────────────────────────────────

  Widget _buildQuickReplies(List<String> replies) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendMessage(replies[i]),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(replies[i],
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ),
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
            // Quick replies toggle
            GestureDetector(
              onTap: () =>
                  setState(() => _showQuickReplies = !_showQuickReplies),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _showQuickReplies
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.neutral100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt,
                    size: 20,
                    color: _showQuickReplies
                        ? AppColors.primary
                        : AppColors.neutral500),
              ),
            ),
            const SizedBox(width: 8),

            // Text input
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
                  onChanged: (v) {
                    if (v.isNotEmpty && _showQuickReplies) {
                      setState(() => _showQuickReplies = false);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                        color: AppColors.neutral400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Send button
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

  Widget _dateDivider(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.neutral400,
                    fontWeight: FontWeight.w500)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _receivedBubble(Map<String, dynamic> msg) {
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
            child: const Icon(Icons.person, size: 14, color: AppColors.primary),
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
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
                  child: Text(msg['text'],
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.neutral900,
                          height: 1.4)),
                ),
                const SizedBox(height: 3),
                Text(msg['time'],
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.neutral400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sentBubble(Map<String, dynamic> msg) {
    final isRead = msg['isRead'] as bool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            child: Text(msg['text'],
                style: const TextStyle(
                    fontSize: 14, color: Colors.white, height: 1.4)),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(msg['time'],
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.neutral400)),
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Report submitted. Thank you.'),
                    backgroundColor: AppColors.neutral600),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: const Text('Report',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
