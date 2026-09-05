import 'dart:async';

import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/notifications/bloc/notification_alerts_cubit.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Connects app lifecycle and persona changes to foreground activity polling.
class NotificationAlertLifecycle extends ConsumerStatefulWidget {
  /// Creates the lifecycle boundary around the application home.
  const NotificationAlertLifecycle({required this.child, super.key});

  /// Application content that remains visually unchanged.
  final Widget child;

  @override
  ConsumerState<NotificationAlertLifecycle> createState() =>
      _NotificationAlertLifecycleState();
}

final class _NotificationAlertLifecycleState
    extends ConsumerState<NotificationAlertLifecycle>
    with WidgetsBindingObserver {
  late final ProviderSubscription<String?> _actorSubscription;
  NotificationAlertsCubit? _monitor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actorSubscription = ref.listenManual<String?>(
      previewActorProvider,
      (_, _) => _syncMonitor(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncMonitor();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncMonitor();

  void _syncMonitor() {
    final monitor = ref.read(notificationAlertsCubitProvider.bloc);
    _monitor = monitor;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState == null || lifecycleState == AppLifecycleState.resumed) {
      unawaited(monitor.resume());
    } else {
      monitor.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitor?.pause();
    _actorSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
