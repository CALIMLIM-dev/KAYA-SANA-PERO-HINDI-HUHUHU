import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/hint_bubble.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/community_provider.dart';
import '../widgets/community_post_card.dart';
import 'community_post_screen.dart';
import 'compose_community_post_screen.dart';
import 'my_community_posts_screen.dart';

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
      final board = context.read<CommunityProvider>();
      await board.load(force: true);
      // It waits to be read before it is on the board, so it is under
      // Your Posts rather than in this list.
      await board.loadMine();
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
        actions: [
          // What you posted, in every state: the board only lists live ones.
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyCommunityPostsScreen()),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Your Posts', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Community', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const HintBubble(
              text: 'Workers post that they are free. Employers and businesses post that they are hiring. Answer a post under it.',
            ),
          ],
        ),
        /*
            A filter button, not four segments.

            All, Workers, Employers and Businesses took the whole width of
            the screen for a choice made once in a while. One button says
            which is showing and opens the four; sort sits beside it.
        */
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _MenuPill<String>(
                  icon: Icons.filter_list,
                  label: _typeLabels[board.type] ?? 'All Posts',
                  active: board.type != 'all',
                  tooltip: 'Filter',
                  current: board.type,
                  options: _typeLabels,
                  onSelected: board.setType,
                ),
                const SizedBox(width: 8),
                /*
                    Newest, oldest, or whatever has been talked about
                    most. Three is all a board of a few hundred notices
                    needs, and "most discussed" is the one that finds the
                    thread worth reading.
                */
                _MenuPill<String>(
                  icon: Icons.swap_vert,
                  label: _sortLabels[board.sort] ?? 'Newest',
                  active: false,
                  tooltip: 'Sort',
                  current: board.sort,
                  options: _sortLabels,
                  onSelected: board.setSort,
                ),
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
              child: const Text('Try Again'),
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

/// What each filter and sort is called on its button.
const Map<String, String> _typeLabels = {
  'all': 'All Posts',
  'worker': 'Workers',
  'employer': 'Employers',
  'business': 'Businesses',
};

const Map<String, String> _sortLabels = {
  'recent': 'Newest',
  'oldest': 'Oldest',
  'discussed': 'Most discussed',
};

/// A small rounded button that says what is chosen and opens the choices.
class _MenuPill<T> extends StatelessWidget {
  const _MenuPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.tooltip,
    required this.current,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;

  /// Narrowed from the default, so it reads as a filter that is on.
  final bool active;
  final String tooltip;
  final T current;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final colour = active ? AppColors.primary : AppColors.neutral700;

    return PopupMenuButton<T>(
      tooltip: tooltip,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final entry in options.entries)
          CheckedPopupMenuItem<T>(
            value: entry.key,
            checked: entry.key == current,
            child: Text(entry.value),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 10, right: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? AppColors.primary.withValues(alpha: 0.35) : AppColors.neutral300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colour),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colour),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: colour),
          ],
        ),
      ),
    );
  }
}
