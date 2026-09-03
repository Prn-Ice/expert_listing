import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget harness() {
    return ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig.parse(
            'http://127.0.0.1:56321/functions/v1/api',
            isRelease: false,
          ),
        ),
      ],
      child: const ExpertListingApp(),
    );
  }

  testWidgets('system light brightness renders the light theme', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(harness());

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.light);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.light.canvas);
  });

  testWidgets('system dark brightness renders the dark theme', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(harness());

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.dark.canvas);
  });

  testWidgets('configuration errors follow system dark appearance', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      const ConfigurationErrorApp(
        AppConfigException('API_BASE_URL is required.'),
      ),
    );

    final context = tester.element(find.byType(Scaffold));
    expect(AppColors.of(context), AppColors.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, AppColors.dark.canvas);
  });
}
