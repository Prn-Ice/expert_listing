import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/notifications/bloc/notifications_bloc.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The server-backed activity destination.
class NotificationsView extends ConsumerStatefulWidget {
  /// Creates the activity destination.
  const NotificationsView({required this.isActive, super.key});

  /// Whether this dashboard destination is currently visible.
  final bool isActive;

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

final class _NotificationsViewState extends ConsumerState<NotificationsView> {
  var _hasStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _start();
  }

  @override
  void didUpdateWidget(covariant NotificationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<NotificationsState>(notificationsBlocProvider, _showNotice);
    final state = ref.watch(notificationsBlocProvider);
    final usesCupertinoRefresh = context.isIos;
    final activity = CustomScrollView(
      key: const PageStorageKey<String>('notifications-scroll'),
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (usesCupertinoRefresh)
          CupertinoSliverRefreshControl(onRefresh: _refresh),
        const SliverToBoxAdapter(child: _NotificationsHeader()),
        if (state.refreshFailed)
          const SliverToBoxAdapter(
            child: _NotificationsInlineStatus(
              message:
                  "Couldn't refresh. Showing the notifications already loaded.",
            ),
          ),
        _NotificationsContent(
          state: state,
          onRetry: _retry,
          onMarkRead: _markRead,
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: usesCupertinoRefresh
          ? activity
          : RefreshIndicator(onRefresh: _refresh, child: activity),
    );
  }

  void _start() {
    if (_hasStarted) return;
    _hasStarted = true;
    ref.read(notificationsBlocProvider.bloc).add(const NotificationsStarted());
  }

  Future<void> _refresh() async {
    final bloc = ref.read(notificationsBlocProvider.bloc);
    if (bloc.state.isInitialLoading || bloc.state.isRefreshing) return;
    bloc.add(const NotificationsRefreshed());
    await bloc.stream.firstWhere(
      (state) => !state.isRefreshing && !state.isInitialLoading,
    );
  }

  void _retry() => ref
      .read(notificationsBlocProvider.bloc)
      .add(const NotificationsRetryRequested());

  void _markRead(int id) => ref
      .read(notificationsBlocProvider.bloc)
      .add(NotificationReadRequested(id));

  void _showNotice(
    NotificationsState? previous,
    NotificationsState next,
  ) {
    if (previous?.noticeSequence == next.noticeSequence ||
        next.notice == null) {
      return;
    }
    AppNotice.show(context, next.notice!);
  }
}

final class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications', style: AppTypography.brand(colors)),
          const SizedBox(height: AppSpacing.xsmall),
          Text(
            'Activity on your posts.',
            style: AppTypography.body(colors, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

final class _NotificationsContent extends StatelessWidget {
  const _NotificationsContent({
    required this.state,
    required this.onRetry,
    required this.onMarkRead,
  });

  final NotificationsState state;
  final VoidCallback onRetry;
  final ValueChanged<int> onMarkRead;

  @override
  Widget build(BuildContext context) {
    if (!state.hasLoaded || state.isInitialLoading) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Semantics(
          label: 'Loading notifications',
          liveRegion: true,
          child: const ExcludeSemantics(
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        ),
      );
    }
    if (state.failure case final failure? when state.notifications.isEmpty) {
      final message = switch (failure) {
        NotificationsFailureKind.connection =>
          "You're offline. Reconnect to load notifications.",
        NotificationsFailureKind.timeout =>
          'Notifications took too long to load.',
        NotificationsFailureKind.service =>
          'Notifications are unavailable. Try again.',
        NotificationsFailureKind.invalidResponse =>
          "Couldn't load notifications.",
      };
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _NotificationsStatus(
          message: message,
          actionLabel: 'Try again',
          onPressed: onRetry,
        ),
      );
    }
    if (state.notifications.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _NotificationsStatus(message: 'No notifications yet.'),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        0,
        AppSpacing.xlarge,
        AppSpacing.xxlarge,
      ),
      sliver: SliverList.separated(
        itemCount: state.notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.medium),
        itemBuilder: (context, index) {
          final notification = state.notifications[index];
          return _NotificationRow(
            key: ValueKey<int>(notification.id),
            notification: notification,
            isReading: state.readingIds.contains(notification.id),
            onMarkRead: () => onMarkRead(notification.id),
          );
        },
      ),
    );
  }
}

final class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.isReading,
    required this.onMarkRead,
    super.key,
  });

  final ActivityNotification notification;
  final bool isReading;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      label: notification.isRead ? 'Read notification' : 'Unread notification',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: notification.isRead ? colors.canvas : colors.brandTint,
          border: Border.all(color: colors.border),
          borderRadius: AppRadii.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(
                imageUrl: notification.actor.avatarUrl,
                displayName: notification.actor.displayName,
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: AppTypography.body(colors),
                        children: [
                          TextSpan(
                            text: notification.actor.displayName,
                            style: AppTypography.bodyStrong(colors),
                          ),
                          const TextSpan(text: ' liked your post.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xsmall),
                    Text(
                      notification.post.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(
                        colors,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xsmall),
                    Text(
                      _timeAgo(notification.createdAt),
                      style: AppTypography.meta(colors),
                    ),
                    if (!notification.isRead) ...[
                      const SizedBox(height: AppSpacing.xsmall),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppButton(
                          minimumSize: const Size(104, 48),
                          borderRadius: AppRadii.pill,
                          overlayColor: colors.subtleSurface,
                          onPressed: isReading ? null : onMarkRead,
                          child: isReading
                              ? Semantics(
                                  label: 'Marking notification as read',
                                  liveRegion: true,
                                  child: const ExcludeSemantics(
                                    child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  'Mark as read',
                                  style: AppTypography.bodyStrong(
                                    colors,
                                    color: colors.brandText,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _NotificationsInlineStatus extends StatelessWidget {
  const _NotificationsInlineStatus({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlarge,
          0,
          AppSpacing.xlarge,
          AppSpacing.medium,
        ),
        child: Text(
          message,
          style: AppTypography.meta(colors, color: colors.textSecondary),
        ),
      ),
    );
  }
}

final class _NotificationsStatus extends StatelessWidget {
  const _NotificationsStatus({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxlarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(colors),
              ),
            ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: AppSpacing.medium),
              AppButton(
                minimumSize: const Size(96, 48),
                borderRadius: AppRadii.pill,
                overlayColor: colors.subtleSurface,
                onPressed: onPressed,
                child: Text(
                  label,
                  style: AppTypography.bodyStrong(
                    colors,
                    color: colors.brandText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _timeAgo(DateTime value) {
  final elapsed = DateTime.now().toUtc().difference(value);
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes}m';
  if (elapsed.inDays < 1) return '${elapsed.inHours}h';
  return '${elapsed.inDays}d';
}
