import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/application_card.dart';

/// Applications Screen with 4 tabs: Pending, Accepted, Rejected, Completed
class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Applications'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.neutral600,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Rejected'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingTab(),
          _AcceptedTab(),
          _RejectedTab(),
          _CompletedTab(),
        ],
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApplicationCard(
            jobTitle: 'Emergency Pipe Repair',
            company: 'Plumbing Services Inc.',
            location: 'Pangasinan',
            appliedDate: '2 days ago',
            status: 'pending',
            salary: '₱1,200/day',
            isVerified: true,
            onTap: () {
              // TODO: Navigate to application details
            },
            onWithdraw: () {
              _showWithdrawDialog(context);
            },
          ),
          const SizedBox(height: 12),
          ApplicationCard(
            jobTitle: 'Electrician Needed',
            company: 'Tech Solutions Inc.',
            location: 'Dagupan City',
            appliedDate: '5 days ago',
            status: 'pending',
            salary: '₱1,800/day',
            isVerified: true,
            onTap: () {},
            onWithdraw: () {
              _showWithdrawDialog(context);
            },
          ),
          const SizedBox(height: 12),
          ApplicationCard(
            jobTitle: 'House Painting',
            company: 'Private Homeowner',
            location: 'Urdaneta City',
            appliedDate: '1 week ago',
            status: 'pending',
            salary: '₱800/day',
            isVerified: false,
            onTap: () {},
            onWithdraw: () {
              _showWithdrawDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw Application'),
        content: const Text('Are you sure you want to withdraw your application? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application withdrawn')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }
}

class _AcceptedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApplicationCard(
            jobTitle: 'Carpenter for Kitchen Cabinets',
            company: 'Baliwag Construction',
            location: 'Pangasinan',
            appliedDate: '3 days ago',
            acceptedDate: '1 day ago',
            status: 'accepted',
            salary: '₱2,500/day',
            isVerified: true,
            onTap: () {},
            onMessage: () {
              // TODO: Navigate to chat
            },
          ),
          const SizedBox(height: 12),
          ApplicationCard(
            jobTitle: 'AC Repair Technician',
            company: 'Cool Air Services',
            location: 'Dagupan City',
            appliedDate: '1 week ago',
            acceptedDate: '5 days ago',
            status: 'accepted',
            salary: '₱1,500/day',
            isVerified: true,
            onTap: () {},
            onMessage: () {},
          ),
        ],
      ),
    );
  }
}

class _RejectedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApplicationCard(
            jobTitle: 'Welder for Metal Gates',
            company: 'Steel Works Co.',
            location: 'Urdaneta City',
            appliedDate: '2 weeks ago',
            rejectedDate: '1 week ago',
            status: 'rejected',
            salary: '₱1,000/day',
            isVerified: true,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _CompletedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ApplicationCard(
            jobTitle: 'Bathroom Tile Installation',
            company: 'Home Depot Services',
            location: 'Pangasinan',
            appliedDate: '1 month ago',
            completedDate: '2 weeks ago',
            status: 'completed',
            salary: '₱2,000/day',
            isVerified: true,
            hasReview: true,
            onTap: () {},
            onReview: () {
              _showReviewDialog(context);
            },
          ),
          const SizedBox(height: 12),
          ApplicationCard(
            jobTitle: 'Roof Leak Repair',
            company: 'Quick Fix Solutions',
            location: 'Dagupan City',
            appliedDate: '2 months ago',
            completedDate: '1 month ago',
            status: 'completed',
            salary: '₱1,500/day',
            isVerified: true,
            hasReview: false,
            onTap: () {},
            onReview: () {
              _showReviewDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave a Review'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rate your experience:'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => IconButton(
                  icon: const Icon(Icons.star_border, color: Colors.amber),
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Show full review form
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}
