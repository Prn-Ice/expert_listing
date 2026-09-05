import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:expert_listing/notifications/view/notifications_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NotificationsView, () {
    testWidgets(
      'shows unread activity and marks it read at 360px in dark mode',
      (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 800)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final read = Completer<DateTime>();
        final repository = _NotificationsRepository(
          load: () async => [_notification],
          markRead: (_) => read.future,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationsRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: AppTheme.dark(platform: TargetPlatform.android),
              home: const Scaffold(body: NotificationsView(isActive: true)),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Notifications'), findsOneWidget);
        expect(
          find.textContaining('Ayo Balogun', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('A useful property update.'), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Unread notification')),
          findsOneWidget,
        );
        expect(tester.getSize(find.text('Mark as read')).height, lessThan(48));
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: find.text('Mark as read'),
                  matching: find.byType(TextButton),
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );

        await tester.tap(find.text('Mark as read'));
        await tester.pump();

        expect(
          find.bySemanticsLabel('Marking notification as read'),
          findsOneWidget,
        );
        read.complete(DateTime.utc(2026, 9, 5, 12, 5));
        await tester.pump();

        expect(
          find.bySemanticsLabel(RegExp('Read notification')),
          findsOneWidget,
        );
        expect(find.text('Mark as read'), findsNothing);
        expect(repository.markReadCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('retries a service failure into an empty 428px destination', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(428, 926)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var attempts = 0;
      final repository = _NotificationsRepository(
        load: () {
          attempts++;
          if (attempts == 1) {
            throw const NotificationsFailure(NotificationsFailureKind.service);
          }
          return Future.value(const []);
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.light(platform: TargetPlatform.android),
            home: const Scaffold(body: NotificationsView(isActive: true)),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Notifications are unavailable. Try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(find.text('No notifications yet.'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('announces initial loading without flashing an empty state', (
      tester,
    ) async {
      final load = Completer<List<ActivityNotification>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(
              _NotificationsRepository(load: () => load.future),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(platform: TargetPlatform.android),
            home: const Scaffold(body: NotificationsView(isActive: true)),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loading notifications'), findsOneWidget);
      expect(find.text('No notifications yet.'), findsNothing);

      load.complete(const []);
      await tester.pump();
      expect(find.text('No notifications yet.'), findsOneWidget);
    });
  });
}

final class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository({required this._load, this._markRead})
    : super(client: Dio());

  final Future<List<ActivityNotification>> Function() _load;
  final Future<DateTime> Function(int)? _markRead;
  int markReadCalls = 0;

  @override
  Future<List<ActivityNotification>> load() => _load();

  @override
  Future<DateTime> markRead(int notificationId) async {
    markReadCalls++;
    return _markRead?.call(notificationId) ?? DateTime.utc(2026, 9, 5, 12, 5);
  }
}

final _notification = ActivityNotification(
  id: 6004,
  createdAt: DateTime.utc(2026, 9, 5, 12),
  readAt: null,
  actor: const ActivityActor(
    handle: 'ayo',
    displayName: 'Ayo Balogun',
    role: 'Property Consultant',
    avatarUrl: null,
  ),
  post: const ActivityPost(id: 1006, body: 'A useful property update.'),
);
