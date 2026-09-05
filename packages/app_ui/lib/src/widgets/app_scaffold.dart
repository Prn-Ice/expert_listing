import 'package:app_ui/src/extensions/build_context_platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The adaptive page surface for an app screen.
///
/// iOS builds a [CupertinoPageScaffold]; every other platform builds a
/// [Scaffold]. The optional bottom bar fills the Material slot on Android
/// and composes beneath the body on iOS, so a screen keeps one layout while
/// each family keeps its native page mechanics.
class AppScaffold extends StatelessWidget {
  /// Creates the page surface.
  const AppScaffold({required this.body, this.bottomNavigationBar, super.key});

  /// The primary page content.
  final Widget body;

  /// The persistent bottom bar.
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    final bar = bottomNavigationBar;
    if (context.isIos) {
      return CupertinoPageScaffold(
        child: bar == null
            ? body
            : Column(
                children: [
                  Expanded(child: body),
                  bar,
                ],
              ),
      );
    }
    return Scaffold(body: body, bottomNavigationBar: bar);
  }
}
