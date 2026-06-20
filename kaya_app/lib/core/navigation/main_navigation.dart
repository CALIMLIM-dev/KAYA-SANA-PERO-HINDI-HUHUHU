import 'package:flutter/material.dart';
import '../../features/jobs/screens/unified_home_screen.dart';
import '../../features/jobs/screens/search_screen.dart';
import '../../features/messaging/screens/messages_list_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../widgets/bottom_nav_bar.dart';

/// Main Navigation with 4 Tabs
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    UnifiedHomeScreen(),
    SearchScreen(),
    MessagesListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
