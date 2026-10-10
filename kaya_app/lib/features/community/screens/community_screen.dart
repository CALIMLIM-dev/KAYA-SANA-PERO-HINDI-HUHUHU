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
        /*
            One compact bar, not four loose chips.

            The chips each took their own padding and border and scrolled
            sideways on a narrow phone. A single segmented bar holds all
            four in the width there is, with sort at the end.
        */
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        for (final entry in const [
                          ('all', 'All'),
                          ('worker', 'Workers'),
                          ('employer', 'Employers'),
                          ('business', 'Businesses'),
                        ])
                          // Widths follow the labels, so all four read at one size.
                          Expanded(
                            flex: entry.$2.length + 3,
                            child: _Segment(
                              label: entry.$2,
                              selected: board.type == entry.$1,
                              onTap: () => board.setType(entry.$1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                /*
                    Newest, oldest, or whatever has been talked about
                    most. Three is all a board of a few hundred notices
                    needs, and "most discussed" is the one that finds the
                    thread worth reading.
                */
                PopupMenuButton<String>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.swap_vert, size: 20),
                  onSelected: board.setSort,
                  itemBuilder: (context) => [
                    for (final option in const [
                      ('recent', 'Newest First'),
                      ('oldest', 'Oldest First'),
                      ('discussed', 'Most Discussed'),
                    ])
                      CheckedPopupMenuItem(
                        value: option.$1,
                        checked: board.sort == option.$1,
                        child: Text(option.$2),
                      ),
                  ],
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

/// One option in the board's filter bar: white and blue when chosen.
class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 1))]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.neutral600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
