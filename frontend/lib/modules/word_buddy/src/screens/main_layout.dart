import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'review_screen.dart';
import 'entry_screen.dart';
import 'stats_screen.dart';
import 'test_screen.dart';
import 'book_management_screen.dart';

// State provider for current screen index
final navigationProvider = StateProvider<int>((ref) => 0);

class ReviewFilter {
  final String? bookId;
  final String? path;
  ReviewFilter({this.bookId, this.path});
}

final reviewFilterProvider = StateProvider<ReviewFilter>((ref) => ReviewFilter());

class MainLayout extends ConsumerWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationProvider);

    final List<Widget> screens = [
      const ReviewScreen(),
      const EntryScreen(),
      const TestScreen(),
      const BookManagementScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回应用选择',
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              ref.read(navigationProvider.notifier).state = index;
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.psychology),
                selectedIcon: Icon(Icons.psychology),
                label: Text('复习'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.add_photo_alternate),
                selectedIcon: Icon(Icons.add_photo_alternate),
                label: Text('录入'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.quiz),
                selectedIcon: Icon(Icons.quiz),
                label: Text('测试'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book),
                selectedIcon: Icon(Icons.book),
                label: Text('单词本'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bar_chart),
                selectedIcon: Icon(Icons.bar_chart),
                label: Text('统计'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: screens[selectedIndex],
          ),
        ],
      ),
    );
  }
}
