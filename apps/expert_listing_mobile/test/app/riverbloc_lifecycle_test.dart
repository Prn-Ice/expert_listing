import 'package:dio/dio.dart';
import 'package:expert_listing/create_post/create_post_image.dart';
import 'package:expert_listing/create_post/post_image_picker.dart';
import 'package:expert_listing/feed/bloc/feed_event.dart';
import 'package:expert_listing/feed/bloc/feed_state.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/notifications/bloc/notifications_bloc.dart';
import 'package:expert_listing/notifications/models/activity_notification.dart';
import 'package:expert_listing/notifications/notifications_providers.dart';
import 'package:expert_listing/notifications/notifications_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverbloc/riverbloc.dart';

class _LifecycleProbeCubit extends Cubit<int> {
  _LifecycleProbeCubit() : super(0);

  int closeCalls = 0;

  void emitNextState() => emit(state + 1);

  @override
  Future<void> close() {
    closeCalls++;
    return super.close();
  }
}

void main() {
  test(
    'Riverbloc provider emits state and closes once with its container',
    () async {
      final provider = BlocProvider<_LifecycleProbeCubit, int>(
        (_) => _LifecycleProbeCubit(),
      );
      final container = ProviderContainer();
      final states = <int>[];
      final subscription = container.listen<int>(
        provider,
        (_, state) => states.add(state),
        fireImmediately: true,
      );

      final cubit = container.read(provider.bloc);
      expect(cubit.state, 0);

      cubit.emitNextState();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(provider), 1);
      expect(states, contains(1));

      subscription.close();
      container.dispose();

      expect(cubit.closeCalls, 1);
    },
  );

  test(
    'FeedBloc emits state and closes once with its Riverbloc provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(_LifecycleFeedRepository()),
        ],
      );
      final subscription = container.listen<FeedState>(
        feedBlocProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final bloc = container.read(feedBlocProvider.bloc)
        ..add(const FeedStarted());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(feedBlocProvider).posts, isEmpty);
      subscription.close();
      container.dispose();

      expect(bloc.isClosed, isTrue);
    },
  );

  test(
    'NotificationsBloc emits state and closes once with its provider',
    () async {
      final container = ProviderContainer(
        overrides: [
          notificationsRepositoryProvider.overrideWithValue(
            _LifecycleNotificationsRepository(),
          ),
        ],
      );
      final subscription = container.listen<NotificationsState>(
        notificationsBlocProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final bloc = container.read(notificationsBlocProvider.bloc)
        ..add(const NotificationsStarted());
      await Future<void>.delayed(Duration.zero);

      expect(container.read(notificationsBlocProvider).notifications, isEmpty);
      subscription.close();
      container.dispose();

      expect(bloc.isClosed, isTrue);
    },
  );

  test(
    'CreatePostCubit emits state and closes with its provider scope',
    () async {
      final container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(_LifecycleFeedRepository()),
          postImagePickerProvider.overrideWithValue(_LifecycleImagePicker()),
        ],
      );
      final subscription = container.listen(
        createPostCubitProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final cubit = container.read(createPostCubitProvider.bloc)
        ..bodyChanged('Retained draft');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(createPostCubitProvider).body, 'Retained draft');
      subscription.close();
      await Future<void>.delayed(Duration.zero);
      container.dispose();

      expect(cubit.isClosed, isTrue);
    },
  );
}

final class _LifecycleImagePicker implements PostImagePicker {
  @override
  Future<List<CreatePostImage>> pickImages({required int limit}) async =>
      const [];
}

final class _LifecycleNotificationsRepository extends NotificationsRepository {
  _LifecycleNotificationsRepository() : super(client: Dio());

  @override
  Future<List<ActivityNotification>> load() async => const [];
}

final class _LifecycleFeedRepository extends FeedRepository {
  _LifecycleFeedRepository()
    : super(
        client: Dio(),
      );

  @override
  Future<FeedLoadResult> loadPage({
    required FeedFilter filter,
    String? cursor,
    int limit = 10,
  }) => Future.value(
    const FeedLoadResult(
      posts: [],
      nextCursor: null,
      source: FeedDataSource.network,
    ),
  );
}
