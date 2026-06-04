import 'package:flutter/material.dart';
import '../../../core/theme/app_tokens.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/label_utils.dart';
import '../../../domain/entities/drink_log.dart';

class RecentLogsWidget extends StatelessWidget {
  final List<DrinkLog> logs;
  final VoidCallback? onMore;

  const RecentLogsWidget({super.key, required this.logs, this.onMore});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('최근 기록',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (onMore != null)
              TextButton(
                onPressed: onMore,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('→ 더보기'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: logs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _LogCard(log: logs[i]),
          ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  final DrinkLog log;

  const _LogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('M/d (E)', 'ko').format(log.drankAt);
    final entries = log.entries;
    final summary = entries.isEmpty
        ? '기록 없음'
        : entries
            .map((e) =>
                '${e.liquorNameRaw} ${e.quantityValue % 1 == 0 ? e.quantityValue.toInt() : e.quantityValue}${unitLabel(e.quantityUnit)}')
            .join(', ');

    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppPalette.accentText(Theme.of(context).brightness))),
              const SizedBox(height: 4),
              Expanded(
                child: Text(summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (log.place != null)
                Text('📍 ${log.place}',
                    style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }

}
