import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../widgets/featured_job_card.dart';

/// Saved Jobs Screen
class SavedJobsScreen extends StatefulWidget {
  const SavedJobsScreen({super.key});

  @override
  State<SavedJobsScreen> createState() => _SavedJobsScreenState();
}

class _SavedJobsScreenState extends State<SavedJobsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Saved Jobs'),
        actions: [
          TextButton(
            onPressed: () {
              _showClearAllDialog();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FeaturedJobCard(
              title: 'Emergency Pipe Repair',
              company: 'Plumbing Services Inc.',
              location: 'Pangasinan',
              rating: '4.8',
              reviews: '(138 reviews)',
              salary: '₱1,200/day',
              isUrgent: true,
              requiresVerification: true,
            ),
            const SizedBox(height: 12),
            FeaturedJobCard(
              title: 'Electrician Needed',
              company: 'Tech Solutions Inc.',
              location: 'Dagupan City',
              rating: '4.7',
              reviews: '(89 reviews)',
              salary: '₱1,800/day',
              requiresVerification: true,
            ),
            const SizedBox(height: 12),
            FeaturedJobCard(
              title: 'Carpenter for Kitchen Cabinets',
              company: 'Baliwag Construction',
              location: 'Pangasinan',
              rating: '4.9',
              reviews: '(156 reviews)',
              salary: '₱2,500/day',
            ),
            const SizedBox(height: 12),
            FeaturedJobCard(
              title: 'House Painting',
              company: 'Private Homeowner',
              location: 'Urdaneta City',
              rating: '4.5',
              reviews: '(23 reviews)',
              salary: '₱800/day',
            ),
            const SizedBox(height: 12),
            FeaturedJobCard(
              title: 'AC Repair Technician',
              company: 'Cool Air Services',
              location: 'Dagupan City',
              rating: '4.6',
              reviews: '(67 reviews)',
              salary: '₱1,500/day',
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Saved Jobs'),
        content: const Text('Are you sure you want to remove all saved jobs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All saved jobs cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
