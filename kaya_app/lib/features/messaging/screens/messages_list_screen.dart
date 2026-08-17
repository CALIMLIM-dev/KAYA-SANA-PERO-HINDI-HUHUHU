import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/realtime_refresh.dart';
import '../../../core/constants/app_mode.dart';
import '../../../providers/app_mode_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/messaging_provider.dart';

/// Conversations List Screen — backed by GET /conversations.
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen>
    with RealtimeRefresh {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  /// The inbox listens to the user's notification feed rather than to every
  /// conversation: it only needs to know that *something* changed, and a
  /// channel per thread would cost one subscription each to learn the same.
  /*
      `application.` as well as `message.`.

      A conversation is created the moment an applicant is accepted, and that
      emits `application.accepted` — not a message. Listening only for messages
      meant the thread existed on the server while this list carried on showing
      the set it fetched at app start, so a new hire's chat was invisible here
      until somebody sent the first message.

      `invitation.` for the same reason: accepting an invitation opens a
      conversation too.
  */
  @override
  List<String> get refreshOn => const ['message.', 'application.', 'invitation.'];

  @override
  void onRealtimeRefresh() =>
      context.read<MessagingProvider>().fetchConversations(silent: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<MessagingProvider>().fetchConversations();
      bindRealtimeRefresh();
    });
  }

  /// Which side of a conversation the signed-in user is on, derived by
  /// comparing employer_id/worker_id against the current user id — the API
  /// already returns both, so no server change was needed for this.
  String _myRole(Map<String, dynamic> conv, int? myId) =>
      conv['worker_id'] == myId ? 'worker' : 'employer';

  Map<String, dynamic>? _otherParty(Map<String, dynamic> conv, String myRole) =>
      (myRole == 'worker' ? conv['employer'] : conv['worker']) as Map<String, dynamic>?;

  List<Map<String, dynamic>> _forMode(
      List<Map<String, dynamic>> conversations, AppMode? mode, int? myId) {
    if (mode == null) return conversations;
    final wanted = mode == AppMode.worker ? 'worker' : 'employer';
    return conversations.where((c) => _myRole(c, myId) == wanted).toList();
  }

  List<Map<String, dynamic>> _filteredFor(
      List<Map<String, dynamic>> conversations, AppMode? mode, int? myId) {
    final query = _searchController.text.toLowerCase();
    return _forMode(conversations, mode, myId).where((c) {
      final myRole = _myRole(c, myId);
      final other = _otherParty(c, myRole);
      final name = (other?['name'] ?? '').toString().toLowerCase();
      final jobTitle = ((c['job'] as Map?)?['title'] ?? '').toString().toLowerCase();
      final unread = (c['unread_count'] as num?)?.toInt() ?? 0;

      final matchesSearch =
          query.isEmpty || name.contains(query) || jobTitle.contains(query);
      final matchesFilter =
          _selectedFilter == 'All' || (_selectedFilter == 'Unread' && unread > 0);
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    // RealtimeRefresh releases its own subscription in its dispose.
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(Map<String, dynamic> conv, String myRole) {
    final other = _otherParty(conv, myRole);
    final job = conv['job'] as Map<String, dynamic>?;

    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': conv['id'],
        'name': other?['name'] ?? (myRole == 'worker' ? 'Employer' : 'Worker'),
        'jobTitle': job?['title'] ?? 'Job',
        'jobId': conv['job_id'],
        'otherUserId': other?['id'],
        'isVerified': (other?['is_verified'] as bool?) ?? false,
        // Drives the activity dot in the chat header. Derived from the other
        // party's last authenticated request, not from a presence channel —
        // see TouchLastSeen for why.
        'lastSeenAt': other?['last_seen_at'],
        // Location sharing is scoped to the hire, and only offered while the
        // job is actually in progress.
        'applicationId': conv['application_id'],
        'jobStatus': job?['status'],
        'myRole': myRole,
        // No presence/online tracking exists yet — omitted rather than faked.
        'otherRole': myRole == 'worker' ? 'employer' : 'worker',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    final myId = context.watch<AuthProvider>().user?['id'] as int?;

    return Consumer<MessagingProvider>(
      builder: (context, provider, _) {
        final conversations = provider.conversations;
        final filtered = _filteredFor(conversations, appMode.mode, myId);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            title: _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search conversations...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                  )
                : const Text('Messages',
                    style: TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: Icon(_isSearching ? Icons.close : Icons.search),
                onPressed: () => setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) _searchController.clear();
                }),
              ),
            ],
          ),
          body: Column(
            children: [
              if (appMode.isHybrid && appMode.mode != null)
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Text(
                    appMode.isWorkerMode
                        ? 'Showing conversations where you applied'
                        : 'Showing conversations for jobs you posted',
                    style: const TextStyle(fontSize: 12, color: AppColors.neutral600),
                  ),
                ),

              Container(
                height: 56,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _chip('All', null),
                    const SizedBox(width: 8),
                    _chip(
                      'Unread',
                      _forMode(conversations, appMode.mode, myId)
                          .where((c) => ((c['unread_count'] as num?) ?? 0) > 0)
                          .length,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: provider.isLoading && conversations.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.errorMessage != null
                        ? _errorState(provider)
                        : filtered.isEmpty
                            ? _emptyState()
                            : RefreshIndicator(
                                onRefresh: () => provider.fetchConversations(),
                                child: ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1, indent: 72),
                                  itemBuilder: (context, i) =>
                                      _conversationTile(filtered[i], myId),
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _errorState(MessagingProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.neutral400),
            const SizedBox(height: 12),
            Text(provider.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.fetchConversations(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.neutral300),
          const SizedBox(height: 16),
          const Text('No conversations yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral600)),
          const SizedBox(height: 8),
          const Text(
              'Conversations unlock once an application is accepted',
              style: TextStyle(fontSize: 13.5, color: AppColors.neutral400),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _chip(String label, int? count) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.neutral100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.neutral300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.neutral700)),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(count.toString(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? AppColors.primary : Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _conversationTile(Map<String, dynamic> conv, int? myId) {
    final myRole = _myRole(conv, myId);
    final other = _otherParty(conv, myRole);
    final job = conv['job'] as Map<String, dynamic>?;
    final unread = (conv['unread_count'] as num?)?.toInt() ?? 0;
    final name = (other?['name'] ?? '').toString();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isVerified = (other?['is_verified'] as bool?) ?? false;
    final updatedAt = conv['updated_at'] as String?;

    return InkWell(
      onTap: () => _openChat(conv, myRole),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                  color: AppColors.neutral900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 14, color: AppColors.success),
                            ],
                          ],
                        ),
                      ),
                      if (updatedAt != null)
                        Text(
                          _timeAgo(updatedAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: unread > 0
                                ? AppColors.primary
                                : AppColors.neutral400,
                            fontWeight:
                                unread > 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    (job?['title'] ?? 'Job').toString(),
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ((conv['latest_message']
                                      as Map<String, dynamic>?)?['message_text'] ??
                                  'No messages yet')
                              .toString(),
                          style: TextStyle(
                            fontSize: 13.5,
                            color: unread > 0
                                ? AppColors.neutral900
                                : AppColors.neutral500,
                            fontWeight:
                                unread > 0 ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
