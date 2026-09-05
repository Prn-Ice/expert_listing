import 'dart:async';

import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/feed/data/bookmark_store.dart';
import 'package:expert_listing/feed/view/post_card.dart';
import 'package:expert_listing/main.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/disabled_notification_alert_service.dart';

/// The engagement journey through real Hono, Postgres, and device preferences.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('likes, comments, bookmarks, and hides a seeded post', (
    tester,
  ) async {
    final config = AppConfig.fromEnvironment();
    const postId = 1002;
    final bookmarks = SharedPreferencesBookmarkStore();
    await _pumpApp(tester, config);
    await _pumpUntilFound(tester, find.byType(PostCard));
    await tester.scrollUntilVisible(
      _post(postId),
      400,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    if ((await tester.runAsync(bookmarks.load))!.contains(postId)) {
      await tester.tap(_action(postId, 'Remove bookmark'));
      await tester.pumpAndSettle();
    }

    if (tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser) {
      await tester.tap(_action(postId, 'Unlike'));
      await _pumpUntil(
        tester,
        () => !tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser,
      );
    }

    final initial = tester.widget<PostCard>(_post(postId)).post;
    await tester.tap(_action(postId, 'Like'));
    await _pumpUntil(
      tester,
      () => tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser,
    );
    expect(
      tester.widget<PostCard>(_post(postId)).post.likeCount,
      initial.likeCount + 1,
    );

    await tester.tap(_action(postId, 'Comments'));
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey<String>('comment-input')),
    );
    const body = 'Integration engagement comment.';
    await tester.enterText(
      find.byKey(const ValueKey<String>('comment-input')),
      body,
    );
    await _pumpUntil(tester, () => _commentSubmitIsEnabled(tester));
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('comment-submit')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('comment-submit')));
    final commentText = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == body,
    );
    await _pumpUntilFound(tester, commentText);
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () =>
          tester.widget<PostCard>(_post(postId)).post.commentCount ==
          initial.commentCount + 1,
    );

    await tester.tap(_action(postId, 'Bookmark'));
    await _pumpUntilFound(tester, _action(postId, 'Remove bookmark'));
    expect(await tester.runAsync(bookmarks.load), contains(postId));
    if (find.text('OK').evaluate().isNotEmpty) {
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(_post(postId));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: _post(postId),
        matching: find.bySemanticsLabel('Post options'),
      ),
    );
    await _pumpUntilFound(tester, find.text('Hide this post'));
    await tester.tap(find.text('Hide this post'));
    await _pumpUntilFound(tester, find.text('Post hidden.'));
    expect(_post(postId), findsNothing);
    await tester.tap(find.text('Undo'));
    await _pumpUntilFound(tester, _post(postId));
    await tester.pumpAndSettle();

    // Restore deterministic actor and device state for another local run.
    if (tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser) {
      await tester.ensureVisible(_action(postId, 'Unlike'));
      await tester.tap(_action(postId, 'Unlike'));
      await _pumpUntil(
        tester,
        () => !tester.widget<PostCard>(_post(postId)).post.likedByCurrentUser,
      );
    }
    if ((await tester.runAsync(bookmarks.load))!.contains(postId)) {
      await tester.ensureVisible(_action(postId, 'Remove bookmark'));
      await tester.tap(_action(postId, 'Remove bookmark'));
      await _pumpUntil(
        tester,
        () async => !(await bookmarks.load()).contains(postId),
      );
    }
  });
}

bool _commentSubmitIsEnabled(WidgetTester tester) {
  final widget = tester.widget<Widget>(
    find.byKey(const ValueKey<String>('comment-submit')),
  );
  return switch (widget) {
    CupertinoButton(:final onPressed) => onPressed != null,
    FilledButton(:final onPressed) => onPressed != null,
    _ => false,
  };
}

Finder _post(int postId) => find.byWidgetPredicate(
  (widget) => widget is PostCard && widget.post.id == postId,
);

Finder _action(int postId, String label) => find.descendant(
  of: find.byKey(ValueKey<String>('post-actions-$postId')),
  matching: find.bySemanticsLabel(
    RegExp('^${RegExp.escape(label)}(?:,|${r'$'})'),
  ),
);

Future<void> _pumpApp(WidgetTester tester, AppConfig config) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        notificationAlertServiceProvider.overrideWithValue(
          DisabledNotificationAlertService(),
        ),
      ],
      child: const ExpertListingApp(),
    ),
  );
  await tester.pump();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) => _pumpUntil(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);

Future<void> _pumpUntil(
  WidgetTester tester,
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    final matched = await tester.runAsync(() async => await condition());
    if (matched ?? false) return;
  }
  fail('Timed out waiting for engagement state.');
}
