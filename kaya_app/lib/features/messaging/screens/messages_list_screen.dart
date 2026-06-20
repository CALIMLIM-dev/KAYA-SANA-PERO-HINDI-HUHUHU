import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/conversation_card.dart';

/// Messages List Screen with Search and Filters
class MessagesListScreen extends StatefulWidget {
  const MessagesListScreen({super.key});

  @override
  State<MessagesListScreen> createState() => _MessagesListScreenState();
}

class _MessagesListScreenState extends State<MessagesListScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.neutral500),
                ),
                style: const TextStyle(color: AppColors.neutral900),
              )
            : const Text('Messages'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: _selectedFilter == 'All',
                  onTap: () => setState(() => _selectedFilter = 'All'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  isSelected: _selectedFilter == 'Unread',
                  count: 3,
                  onTap: () => setState(() => _selectedFilter = 'Unread'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active Jobs',
                  isSelected: _selectedFilter == 'Active Jobs',
                  onTap: () => setState(() => _selectedFilter = 'Active Jobs'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Archived',
                  isSelected: _selectedFilter == 'Archived',
                  onTap: () => setState(() => _selectedFilter = 'Archived'),
                ),
              ],
            ),
          ),
          // Conversations List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ConversationCard(
                    name: 'Plumbing Services Inc.',
                    isVerified: true,
                    lastMessage: 'Great! When can you start the job?',
                    timestamp: '2m ago',
                    unreadCount: 2,
                    jobTitle: 'Emergency Pipe Repair',
                    avatarColor: AppColors.plumbing,
                    onTap: () {
                      // TODO: Navigate to chat screen
                    },
                  ),
                  const Divider(height: 1, indent: 80),
                  ConversationCard(
                    name: 'Tech Solutions Inc.',
                    isVerified: true,
                    lastMessage: 'Thank you for your application',
                    timestamp: '1h ago',
                    unreadCount: 0,
                    jobTitle: 'Electrician Needed',
                    avatarColor: AppColors.electrical,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 80),
                  ConversationCard(
                    name: 'Baliwag Construction',
                    isVerified: true,
                    lastMessage: 'We received your quote. Looking good!',
                    timestamp: '3h ago',
                    unreadCount: 1,
                    jobTitle: 'Carpenter for Kitchen Cabinets',
                    avatarColor: AppColors.carpentry,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 80),
                  ConversationCard(
                    name: 'Cool Air Services',
                    isVerified: false,
                    lastMessage: 'Do you have experience with split-type AC?',
                    timestamp: 'Yesterday',
                    unreadCount: 0,
                    jobTitle: 'AC Repair Technician',
                    avatarColor: AppColors.info,
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 80),
                  ConversationCard(
                    name: 'Home Depot Services',
                    isVerified: true,
                    lastMessage: 'Job completed successfully. Thanks!',
                    timestamp: '2 days ago',
                    unreadCount: 0,
                    jobTitle: 'Bathroom Tile Installation',
                    avatarColor: AppColors.construction,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final int? count;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.neutral100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.neutral300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.neutral700,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
