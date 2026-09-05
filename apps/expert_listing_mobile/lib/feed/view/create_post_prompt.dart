import 'package:app_ui/app_ui.dart';
import 'package:flutter/material.dart';

/// The feed entry point for the later create-post flow.
class CreatePostPrompt extends StatefulWidget {
  /// Creates the prompt.
  const CreatePostPrompt({
    required this.onNotice,
    required this.showInvitation,
    super.key,
  });

  /// Shows a non-stacking boundary notice.
  final ValueChanged<String> onNotice;

  /// Whether initial feed data is ready for the one-shot invitation cue.
  final bool showInvitation;

  @override
  State<CreatePostPrompt> createState() => _CreatePostPromptState();
}

final class _CreatePostPromptState extends State<CreatePostPrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _invitationController;
  late final Animation<double> _outlineOpacity;
  var _hasInvited = false;

  @override
  void initState() {
    super.initState();
    _invitationController = AnimationController(
      vsync: this,
      duration:
          AppMotion.slow + AppMotion.slow + AppMotion.slow + AppMotion.slow,
    );
    _outlineOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 0.72).chain(
          CurveTween(curve: AppMotion.curve),
        ),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 0.72),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.72, end: 0).chain(
          CurveTween(curve: AppMotion.curve),
        ),
        weight: 25,
      ),
    ]).animate(_invitationController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _inviteWhenReady();
  }

  @override
  void didUpdateWidget(CreatePostPrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    _inviteWhenReady();
  }

  void _inviteWhenReady() {
    if (_hasInvited || !widget.showInvitation) return;
    _hasInvited = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
        return;
      }
      _invitationController.forward();
    });
  }

  @override
  void dispose() {
    _invitationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      // Measured prompt geometry: 16px side insets, 8px above, 12px below.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.large,
        AppSpacing.small,
        AppSpacing.large,
        AppSpacing.medium,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: AnimatedBuilder(
          animation: _outlineOpacity,
          builder: (context, child) => DecoratedBox(
            key: const ValueKey<String>('create-post-invitation-outline'),
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: colors.brand.withValues(alpha: _outlineOpacity.value),
              ),
              borderRadius: AppRadii.pill,
            ),
            child: child,
          ),
          child: AppPressable(
            color: colors.subtleSurface,
            borderRadius: AppRadii.pill,
            onPressed: () => widget.onNotice(
              'Post creation is part of the next preview step.',
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xsmall,
                AppSpacing.small,
                12,
                AppSpacing.small,
              ),
              child: Row(
                children: [
                  const AppAvatar.asset(
                    assetName: 'assets/images/current-user.jpg',
                    displayName: 'Prince Adeyemi',
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      'Share a property, Make a request or say something...',
                      style: AppTypography.hint(colors),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
