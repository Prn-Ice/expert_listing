// State fields correspond directly to visible notification conditions.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';

final class NotificationsState extends Equatable {
  const NotificationsState({
    this.notifications = const [],
    this.hasLoaded = false,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.readingIds = const {},
    this.failure,
    this.refreshFailed = false,
    this.noticeSequence = 0,
    this.notice,
  });

  static const initial = NotificationsState();

  final List<ActivityNotification> notifications;
  final bool hasLoaded;
  final bool isInitialLoading;
  final bool isRefreshing;
  final Set<int> readingIds;
  final NotificationsFailureKind? failure;
  final bool refreshFailed;
  final int noticeSequence;
  final String? notice;

  NotificationsState copyWith({
    List<ActivityNotification>? notifications,
    bool? hasLoaded,
    bool? isInitialLoading,
    bool? isRefreshing,
    Set<int>? readingIds,
    NotificationsFailureKind? failure,
    bool clearFailure = false,
    bool? refreshFailed,
    int? noticeSequence,
    String? notice,
    bool clearNotice = false,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      readingIds: readingIds ?? this.readingIds,
      failure: clearFailure ? null : failure ?? this.failure,
      refreshFailed: refreshFailed ?? this.refreshFailed,
      noticeSequence: noticeSequence ?? this.noticeSequence,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    notifications,
    hasLoaded,
    isInitialLoading,
    isRefreshing,
    readingIds,
    failure,
    refreshFailed,
    noticeSequence,
    notice,
  ];
}
