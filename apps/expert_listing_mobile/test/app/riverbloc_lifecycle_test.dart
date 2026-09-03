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
}
