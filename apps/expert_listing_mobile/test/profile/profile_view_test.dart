import 'package:app_ui/app_ui.dart';
import 'package:dio/dio.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/profile/models/profile.dart';
import 'package:expert_listing/profile/profile_providers.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:expert_listing/profile/view/profile_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders profile details at 360px in dark mode', (tester) async {
    tester.view
      ..physicalSize = const Size(360, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
            _ProfileRepository(() async => _result),
          ),
          previewActorUiEnabledProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(platform: TargetPlatform.android),
          home: const Scaffold(body: ProfileView(isActive: true)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Prince Adeyemi'), findsOneWidget);
    expect(find.text('@prince'), findsOneWidget);
    expect(find.text('Realtor'), findsOneWidget);
    expect(find.text('Local preview tools'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries and selects an advertised preview alias', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(428, 926)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var attempts = 0;
    late ProviderContainer container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            profileRepositoryProvider.overrideWithValue(
              _ProfileRepository(() {
                attempts++;
                if (attempts == 1) {
                  throw const ProfileFailure(ProfileFailureKind.service);
                }
                return Future.value(_result);
              }),
            ),
            previewActorUiEnabledProvider.overrideWithValue(true),
          ],
        ),
        child: MaterialApp(
          theme: AppTheme.light(platform: TargetPlatform.android),
          home: const Scaffold(body: ProfileView(isActive: true)),
        ),
      ),
    );
    addTearDown(container.dispose);
    await tester.pump();

    expect(find.text('Profile is unavailable. Try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Previewing @prince'), findsOneWidget);

    await tester.tap(find.text('Previewing @prince'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@ayo'));
    await tester.pumpAndSettle();

    expect(container.read(previewActorProvider), 'ayo');
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}

final class _ProfileRepository extends ProfileRepository {
  _ProfileRepository(this._load) : super(client: Dio());

  final Future<ProfileResult> Function() _load;

  @override
  Future<ProfileResult> load() => _load();
}

const _result = ProfileResult(
  profile: Profile(
    handle: 'prince',
    displayName: 'Prince Adeyemi',
    role: 'Realtor',
    avatarUrl: null,
  ),
  previewActors: ['prince', 'ayo'],
);
