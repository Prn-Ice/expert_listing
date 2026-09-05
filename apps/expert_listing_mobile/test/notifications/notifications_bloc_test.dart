import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/notifications/bloc/notifications_bloc.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NotificationsBloc, () {
    test('loads activity and suppresses duplicate read requests', () async {
      final read = Completer<DateTime>();
      final repository = _NotificationsRepository(
        load: () async => [_notification],
        markRead: (_) => read.future,
      );
      final bloc = NotificationsBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const NotificationsStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.notifications, [_notification]);

      bloc
        ..add(const NotificationReadRequested(6004))
        ..add(const NotificationReadRequested(6004));
      await Future<void>.delayed(Duration.zero);
      expect(repository.markReadCalls, 1);
      expect(bloc.state.readingIds, {6004});

      read.complete(DateTime.utc(2026, 9, 5, 12, 5));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.notifications.single.isRead, isTrue);
      expect(bloc.state.readingIds, isEmpty);
    });

    test('retains visible activity when refresh fails', () async {
      var loads = 0;
      final repository = _NotificationsRepository(
        load: () {
          loads++;
          if (loads == 1) return Future.value([_notification]);
          throw const NotificationsFailure(NotificationsFailureKind.service);
        },
      );
      final bloc = NotificationsBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const NotificationsStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const NotificationsRefreshed());
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.notifications, [_notification]);
      expect(bloc.state.refreshFailed, isTrue);
      expect(bloc.state.failure, isNull);
    });

    test('a stale refresh cannot revert a confirmed read', () async {
      final refresh = Completer<List<ActivityNotification>>();
      var loads = 0;
      final repository = _NotificationsRepository(
        load: () {
          loads++;
          return loads == 1 ? Future.value([_notification]) : refresh.future;
        },
      );
      final bloc = NotificationsBloc(repository: repository);
      addTearDown(bloc.close);

      bloc.add(const NotificationsStarted());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const NotificationsRefreshed());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const NotificationReadRequested(6004));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.notifications.single.isRead, isTrue);

      refresh.complete([_notification]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.notifications.single.isRead, isTrue);
    });

    test(
      'keeps an event unread and emits a useful notice on failure',
      () async {
        final repository = _NotificationsRepository(
          load: () async => [_notification],
          markRead: (_) => Future.error(
            const NotificationsFailure(NotificationsFailureKind.connection),
          ),
        );
        final bloc = NotificationsBloc(repository: repository);
        addTearDown(bloc.close);

        bloc.add(const NotificationsStarted());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const NotificationReadRequested(6004));
        await Future<void>.delayed(Duration.zero);

        expect(bloc.state.notifications.single.isRead, isFalse);
        expect(bloc.state.readingIds, isEmpty);
        expect(
          bloc.state.notice,
          "Couldn't mark that notification as read. Try again.",
        );
        expect(bloc.state.noticeSequence, 1);
      },
    );
  });
}

final class _NotificationsRepository extends NotificationsRepository {
  _NotificationsRepository({
    required this._load,
    this._markRead,
  }) : super(client: Dio());

  final Future<List<ActivityNotification>> Function() _load;
  final Future<DateTime> Function(int)? _markRead;
  int markReadCalls = 0;

  @override
  Future<List<ActivityNotification>> load() => _load();

  @override
  Future<DateTime> markRead(int notificationId) {
    markReadCalls++;
    return _markRead?.call(notificationId) ??
        Future.value(DateTime.utc(2026, 9, 5, 12, 5));
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
