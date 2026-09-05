import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// Preserves root destination state while switching with platform motion.
///
/// This follows Flutter's advanced `NavigationBar` sample: only the incoming
/// and outgoing destinations remain onstage during a Material fade. Cupertino
/// tab changes and reduced-motion changes are immediate.
class DestinationSwitcher extends StatefulWidget {
  /// Creates a switcher for a stable list of root destinations.
  const DestinationSwitcher({
    required this.selectedIndex,
    required this.children,
    super.key,
  });

  /// The index of the destination currently receiving input and semantics.
  final int selectedIndex;

  /// The root destination widgets in navigation order.
  final List<Widget> children;

  @override
  State<DestinationSwitcher> createState() => _DestinationSwitcherState();
}

final class _DestinationSwitcherState extends State<DestinationSwitcher> {
  late final Set<int> _onstageIndices = {widget.selectedIndex};

  @override
  void didUpdateWidget(covariant DestinationSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _onstageIndices
        ..add(oldWidget.selectedIndex)
        ..add(widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.selectedIndex >= 0 &&
          widget.selectedIndex < widget.children.length,
      'selectedIndex must identify one destination child.',
    );
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reducedMotion || context.isIos
        ? Duration.zero
        : AppMotion.medium;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          Positioned.fill(
            child: Offstage(
              offstage: !_onstageIndices.contains(index),
              child: IgnorePointer(
                ignoring: index != widget.selectedIndex,
                child: ExcludeFocus(
                  excluding: index != widget.selectedIndex,
                  child: ExcludeSemantics(
                    excluding: index != widget.selectedIndex,
                    child: AnimatedOpacity(
                      key: ValueKey<String>(
                        'dashboard-destination-transition-$index',
                      ),
                      opacity: index == widget.selectedIndex ? 1 : 0,
                      duration: duration,
                      curve: AppMotion.curve,
                      onEnd: () => _finishTransition(index),
                      child: TickerMode(
                        enabled: index == widget.selectedIndex,
                        child: widget.children[index],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _finishTransition(int index) {
    if (index != widget.selectedIndex || _onstageIndices.length == 1) return;
    setState(() {
      _onstageIndices
        ..clear()
        ..add(widget.selectedIndex);
    });
  }
}
