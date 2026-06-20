import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Conversations List Screen
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // TODO: Replace with MessagingProvider data
  final List<Map<String, dynamic>> _conversations = [
    {
      'id': 1,
      'name': 'Plumbing Services Inc.',
      'isVerified': true,
      'lastMessage': 'Great! When can you start the job?',
      'timestamp': '2m ago',
      'unreadCount': 2,
      'jobTitle': 'Emergency Pipe Repair',
      'isOnline': true,
    },
    {
      'id': 2,
      'name': 'Tech Solutions Inc.',
      'isVerified': true,
      'lastMessage': 'Thank you for your application',
      'timestamp': '1h ago',
      'unreadCount': 0,
      'jobTitle': 'Electrician Needed',
      'isOnline': false,
    },
    {
      'id': 3,
      'name': 'Baliwag Construction',
      'isVerified': true,
      'lastMessage': 'We received your quote. Looking good!',
      'timestamp': '3h ago',
      'unreadCount': 1,
      'jobTitle': 'Carpenter for Kitchen Cabinets',
      'isOnline': true,
    },
    {
      'id': 4,
      'name': 'Cool Air Services',
      'isVerified': false,
      'lastMessage': 'Do you have experience with split-type AC?',
      'timestamp': 'Yesterday',
      'unreadCount': 0,
      'jobTitle': 'AC Repair Technician',
      'isOnline': false,
    },
    {
      'id': 5,
      'name': 'Home Depot Services',
      'isVerified': true,
      'lastMessage': 'Job completed successfully. Thanks!',
      'timestamp': '2 days ago',
      'unreadCount': 0,
      'jobTitle': 'Bathroom Tile Installation',
      'isOnline': false,
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    final query = _searchController.text.toLowerCase();
    return _conversations.where((c) {
      final matchesSearch = query.isEmpty ||
          c['name'].toString().toLowerCase().contains(query) ||
          c['jobTitle'].toString().toLowerCase().contains(query);
      final matchesFilter = _selectedFilter == 'All' ||
          (_selectedFilter == 'Unread' && c['unreadCount'] > 0);
      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openChat(Map<String, dynamic> conversation) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'conversationId': conversation['id'],
        'name': conversation['name'],
        'jobTitle': conversation['jobTitle'],
        'isVerified': conversation['isVerified'],
        'isOnline': conversation['isOnline'],
      },
    );
    // Mark as read
    setState(() => conversation['unreadCount'] = 0);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
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
          // ── Filter chips ──
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
                _chip('Unread',
                    _conversations.where((c) => c['unreadCount'] > 0).length),
              ],
            ),
          ),

          // ── Conversation list ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 56, color: AppColors.neutral300),
                        const SizedBox(height: 16),
                        const Text('No conversations yet',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral600)),
                        const SizedBox(height: 8),
                        const Text(
                            'Conversations unlock once an application is accepted',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.neutral400),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async =>
                        await Future.delayed(const Duration(seconds: 1)),
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (context, i) =>
                          _conversationTile(filtered[i]),
                    ),
                  ),
          ),
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
                    fontSize: 13,
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

  Widget _conversationTile(Map<String, dynamic> conv) {
    final unread = conv['unreadCount'] as int;
    final initial = conv['name'].toString()[0].toUpperCase();

    return InkWell(
      onTap: () => _openChat(conv),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
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
                if (conv['isOnline'] == true)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + last message
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
                                conv['name'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.neutral900,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conv['isVerified'] == true) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified,
                                  size: 14, color: AppColors.success),
                            ],
                          ],
                        ),
                      ),
                      Text(
                        conv['timestamp'],
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? AppColors.primary
                              : AppColors.neutral400,
                          fontWeight: unread > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conv['jobTitle'],
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
                          conv['lastMessage'],
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.neutral900
                                : AppColors.neutral500,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
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
}
