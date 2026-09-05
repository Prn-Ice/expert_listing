import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/profile/bloc/profile_cubit.dart';
import 'package:expert_listing/profile/models/profile.dart';
import 'package:expert_listing/profile/profile_providers.dart';
import 'package:expert_listing/profile/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The server-backed current-user Profile destination.
class ProfileView extends ConsumerStatefulWidget {
  /// Creates the Profile destination.
  const ProfileView({required this.isActive, super.key});

  /// Whether this dashboard destination is currently visible.
  final bool isActive;

  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

final class _ProfileViewState extends ConsumerState<ProfileView> {
  var _hasStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _start();
  }

  @override
  void didUpdateWidget(covariant ProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileCubitProvider);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('profile-scroll'),
        primary: false,
        slivers: [
          const SliverToBoxAdapter(child: _ProfileHeader()),
          SliverFillRemaining(
            hasScrollBody: false,
            child: _ProfileContent(
              state: state,
              onRetry: _retry,
              onChooseActor: _chooseActor,
            ),
          ),
        ],
      ),
    );
  }

  void _start() {
    if (_hasStarted) return;
    _hasStarted = true;
    unawaited(ref.read(profileCubitProvider.bloc).load());
  }

  void _retry() => unawaited(ref.read(profileCubitProvider.bloc).load());

  Future<void> _chooseActor(List<String> actors, String currentHandle) async {
    final alias = await AppSheet.show<String>(
      context,
      child: _PreviewActorSheet(
        actors: actors,
        currentHandle: currentHandle,
      ),
    );
    if (alias == null || !mounted) return;
    ref.read(previewActorProvider.notifier).select(alias);
  }
}

final class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.large,
      ),
      child: Text('Profile', style: AppTypography.brand(colors)),
    );
  }
}

final class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.state,
    required this.onRetry,
    required this.onChooseActor,
  });

  final ProfileState state;
  final VoidCallback onRetry;
  final void Function(List<String>, String) onChooseActor;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (state.failure case final failure?) {
      final message = switch (failure.kind) {
        ProfileFailureKind.connection =>
          "You're offline. Reconnect to load your profile.",
        ProfileFailureKind.timeout => 'Profile took too long to load.',
        ProfileFailureKind.service => 'Profile is unavailable. Try again.',
        ProfileFailureKind.invalidResponse => "Couldn't load your profile.",
      };
      return _ProfileStatus(message: message, onRetry: onRetry);
    }
    final profile = state.profile;
    if (profile == null) return const SizedBox.shrink();
    return _ProfileDetails(
      profile: profile,
      previewActors: state.previewActors,
      onChooseActor: onChooseActor,
    );
  }
}

final class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({
    required this.profile,
    required this.previewActors,
    required this.onChooseActor,
  });

  final Profile profile;
  final List<String> previewActors;
  final void Function(List<String>, String) onChooseActor;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.xxlarge,
        AppSpacing.xlarge,
        AppSpacing.xxlarge,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppAvatar(
            imageUrl: profile.avatarUrl,
            displayName: profile.displayName,
            size: 96,
          ),
          const SizedBox(height: AppSpacing.xlarge),
          Text(
            profile.displayName,
            textAlign: TextAlign.center,
            style: AppTypography.brand(colors),
          ),
          const SizedBox(height: AppSpacing.xsmall),
          Text(
            '@${profile.handle}',
            style: AppTypography.bodyMedium(
              colors,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.small),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.brandTint,
              borderRadius: AppRadii.pill,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.medium,
                vertical: AppSpacing.small,
              ),
              child: Text(
                profile.role,
                style: AppTypography.caption(
                  colors,
                  color: colors.brandText,
                ),
              ),
            ),
          ),
          if (previewActors.length > 1) ...[
            const SizedBox(height: AppSpacing.xxlarge),
            Divider(color: colors.border, height: 1),
            const SizedBox(height: AppSpacing.large),
            Text(
              'Demo personas',
              style: AppTypography.bodyStrong(colors),
            ),
            const SizedBox(height: AppSpacing.xsmall),
            Text(
              'Switch persona to explore current-user states.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                colors,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            AppButton(
              minimumSize: const Size(double.infinity, 48),
              borderRadius: AppRadii.pill,
              overlayColor: colors.subtleSurface,
              onPressed: () => onChooseActor(
                previewActors,
                profile.handle,
              ),
              child: Text(
                'Previewing @${profile.handle}',
                style: AppTypography.bodyStrong(
                  colors,
                  color: colors.brandText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _PreviewActorSheet extends StatelessWidget {
  const _PreviewActorSheet({
    required this.actors,
    required this.currentHandle,
  });

  final List<String> actors;
  final String currentHandle;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.large,
        AppSpacing.xlarge,
        AppSpacing.xlarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preview as', style: AppTypography.brand(colors)),
          const SizedBox(height: AppSpacing.medium),
          for (final actor in actors)
            Semantics(
              selected: actor == currentHandle,
              child: AppButton(
                minimumSize: const Size(double.infinity, 48),
                alignment: Alignment.centerLeft,
                borderRadius: AppRadii.pill,
                overlayColor: colors.subtleSurface,
                onPressed: () => Navigator.of(context).pop(actor),
                child: Text(
                  '@$actor${actor == currentHandle ? ' (Current)' : ''}',
                  style: AppTypography.bodyMedium(colors),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _ProfileStatus extends StatelessWidget {
  const _ProfileStatus({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxlarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.body(colors),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            AppButton(
              minimumSize: const Size(96, 48),
              borderRadius: AppRadii.pill,
              overlayColor: colors.subtleSurface,
              onPressed: onRetry,
              child: Text(
                'Try again',
                style: AppTypography.bodyStrong(
                  colors,
                  color: colors.brandText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
