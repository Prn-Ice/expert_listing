import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (error) {
    runApp(ConfigurationErrorApp(error));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const ExpertListingApp(),
    ),
  );
}

/// Root application widget for the Expert Listing mobile experience.
class ExpertListingApp extends StatelessWidget {
  /// Creates the application shell.
  const ExpertListingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Light is the Figma reference; dark follows the same semantic roles.
      // The system appearance selects between them; there is no in-app
      // selector because the design does not contain one.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const DashboardPage(),
    );
  }
}

/// The startup surface for a missing or invalid public configuration.
class ConfigurationErrorApp extends StatelessWidget {
  /// Creates the error surface with a safe, actionable message.
  const ConfigurationErrorApp(this.error, {super.key});

  /// The configuration failure to describe.
  final AppConfigException error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxlarge),
            child: Text(
              'The app is not configured correctly.\n${error.message}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
