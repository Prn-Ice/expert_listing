import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:flutter/material.dart';

/// The feed entry point for the later create-post flow.
class CreatePostPrompt extends StatefulWidget {
  /// Creates the prompt.
  const CreatePostPrompt({
    required this.actorIdentity,
    required this.onPressed,
    required this.showInvitation,
    super.key,
  });

  /// Opens the create-post sheet.
  final VoidCallback onPressed;

  /// The active preview actor represented by the prompt avatar.
  final PreviewActorIdentity actorIdentity;

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
      // The 12px pill inset and 8px leading pad align its avatar with the
      // 20px post inset while leaving the pill edge visibly outside it.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        AppSpacing.small,
        AppSpacing.medium,
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
            onPressed: widget.onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.small,
                AppSpacing.small,
                AppSpacing.medium,
                AppSpacing.small,
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    key: const ValueKey<String>('create-post-avatar-border'),
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.border),
                    ),
                    child: AppAvatar.asset(
                      assetName: widget.actorIdentity.assetName,
                      displayName: widget.actorIdentity.displayName,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Text(
                      'Share a property, Make a request or say something...',
                      style: AppTypography.hint(
                        colors,
                        color: colors.textTertiary,
                      ),
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
