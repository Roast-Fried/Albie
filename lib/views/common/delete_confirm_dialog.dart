import 'package:flutter/material.dart';

/// 공통 삭제 확인 다이얼로그 — true 반환 시 삭제 확인
Future<bool?> showDeleteConfirmDialog(
  BuildContext context, {
  String title = '기록 삭제',
  String content = '이 기록을 삭제하시겠습니까?',
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('삭제',
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      ],
    ),
  );
}
