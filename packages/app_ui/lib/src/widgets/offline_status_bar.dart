import 'package:app_ui/src/tokens/colors.dart';
import 'package:app_ui/src/tokens/spacing.dart';
import 'package:app_ui/src/tokens/typography.dart';
import 'package:flutter/material.dart';

/// A persistent strip describing saved or stale feed provenance.
///
/// Unlike AppNotice this stays on screen while its condition holds; the
/// owning feature decides visibility.
class OfflineStatusBar extends StatelessWidget {
  /// Creates the provenance strip.
  const OfflineStatusBar({required this.message, super.key});

  /// The provenance description, for example "Showing saved posts.".
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return ColoredBox(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.small,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: AppTypography.meta(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
