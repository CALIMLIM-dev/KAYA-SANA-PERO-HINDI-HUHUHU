import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hint_bubble.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import '../widgets/community_post_card.dart';
import 'community_post_screen.dart';
import 'compose_community_post_screen.dart';

/*
    The community board, as a tab.

    Workers saying they are free, businesses saying they are hiring. It is
    not the job feed: nothing here is applied to, and nobody is hired
    through it. A notice is read, and the poster is messaged.
*/
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityProvider>().load();
    });
  }

  Future<void> _compose() async {
    final auth = context.read<AuthProvider>();
    if (!auth.workerProfileExists && !auth.employerProfileExists) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Set up a profile first, then you can post here.'),
      ));
      return;
    }

    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ComposeCommunityPostScreen()),
    );
    if (posted == true && mounted) {
      await context.read<CommunityProvider>().load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = context.watch<CommunityProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Community', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const HintBubble(
              text: 'Workers post that they are free. Businesses post that they are hiring. Message a poster to talk.',
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                for (final entry in const [
                  ('all', 'All'),
                  ('worker', 'Workers'),
                  ('business', 'Businesses'),
                ]) ...[
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: board.type == entry.$1,
                    onSelected: (_) => board.setType(entry.$1),
                    backgroundColor: Colors.white,
                    selectedColor: AppColors.primary.withValues(alpha: 0.12),
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: board.type == entry.$1 ? AppColors.primary : AppColors.neutral600,
                    ),
                    side: BorderSide(
                      color: board.type == entry.$1 ? AppColors.primary : AppColors.neutral300,
                    ),
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'community-post',
        onPressed: _compose,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Post'),
      ),
      body: RefreshIndicator(
        onRefresh: () => board.load(force: true),
        child: _body(board),
      ),
    );
  }

  Widget _body(CommunityProvider board) {
    if (board.isLoading && !board.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (board.error != null && board.posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Text(board.error!, textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.neutral600)),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => board.load(force: true),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (board.posts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: const [
          SizedBox(height: 48),
          Icon(Icons.forum_outlined, size: 48, color: AppColors.neutral400),
          SizedBox(height: 12),
          Text(
            'Nothing posted yet. Be the first.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.neutral600, height: 1.4),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: board.posts.length,
      itemBuilder: (context, i) {
        final post = board.posts[i];
        return CommunityPostCard(
          post: post,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CommunityPostScreen(post: post)),
          ),
        );
      },
    );
  }
}
