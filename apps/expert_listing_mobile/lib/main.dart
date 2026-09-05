import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/app_config.dart';
import 'package:expert_listing/app/providers.dart';
import 'package:expert_listing/dashboard/dashboard_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const ExpertListingApp({super.key, this.platformOverride});

  /// Injectable platform that tests use to exercise each native root.
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    return _NativeRoot(
      platformOverride: platformOverride,
      home: const DashboardPage(),
    );
  }
}

/// The startup surface for a missing or invalid public configuration.
class ConfigurationErrorApp extends StatelessWidget {
  /// Creates the error surface with a safe, actionable message.
  const ConfigurationErrorApp(this.error, {super.key, this.platformOverride});

  /// The configuration failure to describe.
  final AppConfigException error;

  /// Injectable platform that tests use to exercise each native root.
  final TargetPlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    return _NativeRoot(
      platformOverride: platformOverride,
      home: _ConfigurationErrorPage(error: error),
    );
  }
}

/// The native root policy shared by every application surface.
///
/// iOS renders a CupertinoApp root; every other platform renders a
/// MaterialApp root. Both build their themes from the same semantic palettes,
/// so system appearance changes restyle either native component family.
class _NativeRoot extends StatelessWidget {
  const _NativeRoot({required this.platformOverride, required this.home});

  final TargetPlatform? platformOverride;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    final platform = platformOverride ?? defaultTargetPlatform;
    // The root view's MediaQuery carries the system appearance, so the
    // Cupertino theme and the hosted Material theme rebuild with it.
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;

    return switch (platform) {
      TargetPlatform.iOS => CupertinoApp(
        debugShowCheckedModeBanner: false,
        // Built from the same semantic palettes as the Material themes.
        theme: AppTheme.cupertino(brightness),
        builder: (context, navigator) => Theme(
          // A standard Theme carrying the shared semantic extension and the
          // selected platform for the Material widgets still hosted under
          // the Cupertino root.
          data: AppTheme.material(brightness, platform: platform),
          child: ScaffoldMessenger(child: navigator!),
        ),
        localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
        home: home,
      ),
      _ => MaterialApp(
        debugShowCheckedModeBanner: false,
        // Light is the Figma reference; dark follows the same semantic
        // roles. The system appearance selects between them; there is no
        // in-app selector because the design does not contain one.
        theme: AppTheme.light(platform: platform),
        darkTheme: AppTheme.dark(platform: platform),
        home: home,
      ),
    };
  }
}

/// The error page shown when the application is not correctly configured.
class _ConfigurationErrorPage extends StatelessWidget {
  const _ConfigurationErrorPage({required this.error});

  final AppConfigException error;

  @override
  Widget build(BuildContext context) {
    // The error surface owns the status bar like every other screen.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
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
