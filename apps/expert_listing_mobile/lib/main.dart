import 'package:expert_listing/app/app_config.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(ExpertListingApp(config: AppConfig.fromEnvironment()));
}

/// Root application widget for the Expert Listing mobile experience.
class ExpertListingApp extends StatelessWidget {
  /// Creates the application with the validated public configuration.
  const ExpertListingApp({required this.config, super.key});

  /// The validated configuration available to application composition.
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Expert Listing'))),
    );
  }
}
