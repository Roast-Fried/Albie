import 'package:flutter/material.dart';
import '../archive/archive_screen.dart';
import '../calendar/calendar_screen.dart';
import '../common/animations.dart';
import '../stats/stats_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.wine_bar),
            title: const Text('마셔본 술'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchiveScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('통계'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('음주 캘린더'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context, fadeSlideRoute(const CalendarScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}
