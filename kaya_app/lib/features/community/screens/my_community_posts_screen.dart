import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/community_provider.dart';
import '../widgets/community_post_card.dart';
import 'community_post_screen.dart';

/*
    The notices you have posted, in every state.

    The board only lists what is live, so a post waiting to be read, a
    refused one and an ended one were nowhere: "Sent for review" and then
    nothing to look at, and a refusal with its reason that could not be
    opened. Here they all are, newest first.
*/
class MyCommunityPostsScreen extends StatefulWidget {
  const MyCommunityPostsScreen({super.key});

  @override
  State<MyCommunityPostsScreen> createState() => _MyCommunityPostsScreenState();
}

class _MyCommunityPostsScreenState extends State<MyCommunityPostsScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<CommunityProvider>().loadMine();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final mine = context.watch<CommunityProvider>().mine;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: AppColors.neutral900,
        title: const Text('Your Posts', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: !_loaded && mine.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : mine.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(32),
                    children: const [
                      SizedBox(height: 48),
                      Icon(Icons.forum_outlined, size: 48, color: AppColors.neutral400),
                      SizedBox(height: 12),
                      Text(
                        'You have not posted anything yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.neutral600, height: 1.4),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: mine.length,
                    itemBuilder: (context, i) {
                      final post = mine[i];
                      return CommunityPostCard(
                        post: post,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CommunityPostScreen(post: post)),
                          );
                          // It may have been withdrawn or taken down.
                          if (mounted) _load();
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
