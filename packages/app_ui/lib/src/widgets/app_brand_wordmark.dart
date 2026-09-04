import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The exact Expert Listing wordmark at its committed visual dimensions.
class AppBrandWordmark extends StatelessWidget {
  /// Creates the shared Expert Listing wordmark.
  const AppBrandWordmark({this.color, super.key});

  /// Optional semantic colour applied to the complete wordmark.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return SvgPicture.asset(
      'assets/brand/expert-listing-wordmark.svg',
      package: 'app_ui',
      width: 169,
      height: 22,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
