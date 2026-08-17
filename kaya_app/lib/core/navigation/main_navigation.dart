import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/jobs/screens/unified_home_screen.dart';
import '../../features/jobs/screens/search_screen.dart';
import '../../features/messaging/screens/messages_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../providers/messaging_provider.dart';
import '../../providers/notification_provider.dart';
import '../widgets/bottom_nav_bar.dart';

/// Main Navigation with 4 Tabs
///
/// The tabs live in an [IndexedStack] so each keeps its scroll position and
/// state when you switch away. That is the right behaviour, but it has a cost
/// that was being paid silently: every tab is built once, when this screen
/// mounts, and `initState` never runs again. A screen that loads its data in
/// `initState` therefore loads it *once, at app start* and never afterwards.
///
/// For the inbox that meant the conversation list was fetched before any
/// conversation existed. An employer accepted an applicant, opened Messages,
/// and saw nothing — while opening the same chat directly from the applicant
/// worked, because that path navigates by id and skips the stale list.
///
/// The app leaned on realtime to paper over this, and realtime is not
/// guaranteed: Reverb may be down, and its host is not always reachable from
/// the phone. Data correctness cannot depend on a socket being up, so the tabs
/// refresh when you open them and when the app returns to the foreground.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  static const int _messagesTab = 2;

  final List<Widget> _screens = const [
    UnifiedHomeScreen(),
    SearchScreen(),
    MessagesListScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Anything could have happened while the app was in the background — and if
  /// the socket dropped there, no event arrived to say so.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshForTab(_currentIndex);
      // The badge is visible from every tab, so it is refreshed regardless of
      // which one is open.
      context.read<NotificationProvider>().load(force: true);
    }
  }

  void _refreshForTab(int index) {
    if (index == _messagesTab) {
      context.read<MessagingProvider>().fetchConversations(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          // Silent: the list is already on screen, so a spinner over existing
          // content would read as a bug rather than as freshness.
          _refreshForTab(index);
        },
      ),
    );
  }
}
