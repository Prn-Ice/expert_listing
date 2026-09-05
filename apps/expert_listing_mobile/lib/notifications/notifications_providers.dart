import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/notifications/bloc/notifications_bloc.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:riverbloc/riverbloc.dart';

/// The Hono activity-notification boundary.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepository(client: ref.watch(httpClientProvider));
});

/// The request-scoped notification behavior lifecycle.
final notificationsBlocProvider =
    BlocProvider<NotificationsBloc, NotificationsState>((ref) {
      return NotificationsBloc(
        repository: ref.watch(notificationsRepositoryProvider),
      );
    });
