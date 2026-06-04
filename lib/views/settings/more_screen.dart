import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_tokens.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _sectionLabel(context, '둘러보기'),
          _tile(context,
              key: 'more_archive',
              icon: AppIcons.drinkFilled,
              title: '마셔본 술',
              route: Routes.archive),
          _tile(context,
              key: 'more_stats',
              icon: AppIcons.stats,
              title: '통계',
              route: Routes.stats),
          _tile(context,
              key: 'more_calendar',
              icon: AppIcons.calendar,
              title: '음주 캘린더',
              route: Routes.calendar),
          _tile(context,
              key: 'more_condition',
              icon: AppIcons.condition,
              title: '컨디션 로그',
              subtitle: '음주 다음날 숙취·수면 기록',
              route: Routes.conditionLog),
          const Divider(),
          _sectionLabel(context, '설정'),
          _tile(context,
              key: 'more_settings',
              icon: AppIcons.settings,
              title: '설정',
              route: Routes.settings),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
        child: Text(text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  // amber primary 는 light 소형 텍스트 AA 미달 → accentText.
                  color: AppPalette.accentText(Theme.of(context).brightness),
                )),
      );

  Widget _tile(
    BuildContext context, {
    required String key,
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
  }) {
    return ListTile(
      key: Key(key),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(AppIcons.chevron),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}
