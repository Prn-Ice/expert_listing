import 'package:app_ui/app_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// An action available from a feed post's overflow menu.
enum PostOption {
  /// Copies the post's truthful text representation.
  copyDetails,

  /// Hides the post for the current session.
  hide,
}

/// Shows the platform-adaptive menu anchored to a post overflow control.
Future<PostOption?> showPostOptionsMenu(
  BuildContext context, {
  required Rect sourceRect,
  required Size overlaySize,
}) {
  final colors = AppColors.of(context);
  if (context.isIos) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return showGeneralDialog<PostOption>(
      context: context,
      barrierDismissible: true,
      barrierLabel: CupertinoLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: disableAnimations ? Duration.zero : AppMotion.fast,
      pageBuilder: (dialogContext, _, _) => _CupertinoPostOptionsMenu(
        sourceRect: sourceRect,
        onSelected: (option) => Navigator.pop(dialogContext, option),
      ),
      transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.curve),
        child: child,
      ),
    );
  }

  return showMenu<PostOption>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
      sourceRect,
      Offset.zero & overlaySize,
    ),
    color: colors.canvas,
    surfaceTintColor: Colors.transparent,
    shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
    menuPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xsmall),
    constraints: const BoxConstraints(minWidth: 200),
    items: [
      PopupMenuItem(
        value: PostOption.copyDetails,
        child: Text('Copy post details', style: AppTypography.body(colors)),
      ),
      PopupMenuItem(
        value: PostOption.hide,
        child: Text('Hide this post', style: AppTypography.body(colors)),
      ),
    ],
  );
}

final class _CupertinoPostOptionsMenu extends StatelessWidget {
  const _CupertinoPostOptionsMenu({
    required this.sourceRect,
    required this.onSelected,
  });

  static const _width = 220.0;
  static const _itemHeight = 48.0;
  static const double _edgeInset = AppSpacing.small;
  static const double _anchorGap = AppSpacing.xsmall;

  final Rect sourceRect;
  final ValueChanged<PostOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const menuHeight = _itemHeight * 2 + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = (sourceRect.right - _width).clamp(
          _edgeInset,
          constraints.maxWidth - _width - _edgeInset,
        );
        final below = sourceRect.bottom + _anchorGap;
        final top = below + menuHeight <= constraints.maxHeight - _edgeInset
            ? below
            : sourceRect.top - menuHeight - _anchorGap;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: _width,
              child: CupertinoPopupSurface(
                key: const ValueKey<String>('cupertino-post-options-menu'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CupertinoButton(
                      minimumSize: const Size.fromHeight(_itemHeight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large,
                      ),
                      alignment: Alignment.centerLeft,
                      borderRadius: BorderRadius.zero,
                      onPressed: () => onSelected(PostOption.copyDetails),
                      child: Text(
                        'Copy post details',
                        style: AppTypography.body(colors),
                      ),
                    ),
                    Container(height: 1, color: colors.border),
                    CupertinoButton(
                      minimumSize: const Size.fromHeight(_itemHeight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.large,
                      ),
                      alignment: Alignment.centerLeft,
                      borderRadius: BorderRadius.zero,
                      onPressed: () => onSelected(PostOption.hide),
                      child: Text(
                        'Hide this post',
                        style: AppTypography.body(colors),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
