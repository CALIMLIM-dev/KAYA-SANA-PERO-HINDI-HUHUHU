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

  static const int homeTab = 0;
  static const int searchTab = 1;
  static const int messagesTab = 2;
  static const int profileTab = 3;

  /// Which tab the shell is showing.
  ///
  /// Held outside the State so a screen pushed on top can ask for a tab
  /// without needing a reference to the shell underneath it.
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(homeTab);

  /*
      Go to a tab, from anywhere.

      Screens pushed over the shell used to reach the inbox with
      `pushNamed('/messages')`, which mounts MessagesListScreen on its own —
      correct content, but stacked *above* the shell, so the bottom navigation
      disappeared and the only way out was the back gesture. Tapping "Message"
      on a worker's profile therefore looked like it had dropped the user out
      of the app.

      A tab is not a screen you push. This selects the tab on the shell that is
      already mounted and unwinds whatever was pushed over it, which is what
      every other app does when you tap into a section.
  */
  static void openTab(BuildContext context, int index) {
    selectedTab.value = index;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// The inbox, with the navigation bar still under it.
  static void openMessages(BuildContext context) =>
      openTab(context, messagesTab);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  late int _currentIndex = MainNavigation.selectedTab.value;

  static const int _messagesTab = MainNavigation.messagesTab;

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
    MainNavigation.selectedTab.addListener(_onTabRequested);

    /*
        Notification polling starts here, where a session actually begins.

        It used to start in the banner host, which is created once with the
        MaterialApp — before anyone has logged in. That was wrong twice over.

        The first poll went out with no token, and a 401 from a path that is
        not an auth endpoint is treated as an expired session, so every cold
        start fired a spurious forced logout.

        Worse, logging out calls clear(), which stops the timer, and nothing
        ever started it again — the banner host's initState had already run and
        does not run a second time. So a single sign-out killed pop-up
        notifications for the rest of the app's life, silently.

        This shell is mounted after login and rebuilt on every sign-in, which
        makes it the right owner. startPolling() is idempotent, so returning to
        this screen does not stack timers.
    */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationProvider>().startPolling();
    });
  }

  @override
  void dispose() {
    MainNavigation.selectedTab.removeListener(_onTabRequested);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Something asked for a tab — either the bar below, or a screen that was
  /// pushed on top and has now unwound itself.
  void _onTabRequested() {
    final index = MainNavigation.selectedTab.value;
    if (!mounted || index == _currentIndex) return;

    setState(() => _currentIndex = index);
    _refreshForTab(index);
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
        // Routed through the same notifier as an external request, so there is
        // one path that changes the tab rather than two that can disagree.
        // _onTabRequested does the setState and the silent refresh — silent
        // because the list is already on screen, and a spinner over existing
        // content reads as a bug rather than as freshness.
        onTap: (index) => MainNavigation.selectedTab.value = index,
      ),
    );
  }
}
