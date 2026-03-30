import 'package:flutter/material.dart';

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
            onTap: () {}, // TODO: navigate to archive
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('통계'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: navigate to stats
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: navigate to settings
          ),
        ],
      ),
    );
  }
}
