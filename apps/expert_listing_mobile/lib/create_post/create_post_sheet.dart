import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/create_post/create_post_cubit.dart';
import 'package:expert_listing/create_post/create_post_state.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Opens one retained create-post flow and returns its published post.
Future<FeedPost?> showCreatePostSheet(BuildContext context) {
  return AppSheet.show<FeedPost>(
    context,
    child: const CreatePostSheet(),
  );
}

/// The adaptive create-post form owned by [CreatePostCubit].
class CreatePostSheet extends ConsumerStatefulWidget {
  /// Creates the sheet.
  const CreatePostSheet({super.key});

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

final class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  late final TextEditingController _bodyController = TextEditingController();
  late final TextEditingController _locationController =
      TextEditingController();
  final _bodyFocus = FocusNode();
  var _discardApproved = false;
  var _askingDiscard = false;

  @override
  void dispose() {
    _bodyController.dispose();
    _locationController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostCubitProvider);
    final cubit = ref.read(createPostCubitProvider.bloc);
    final colors = AppColors.of(context);

    return PopScope<FeedPost>(
      canPop: _discardApproved || !state.isPopulated,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close(state));
      },
      child: ListView(
        key: const ValueKey<String>('create-post-sheet'),
        primary: true,
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.large,
          AppSpacing.small,
          AppSpacing.large,
          AppSpacing.xlarge,
        ),
        children: [
          Row(
            children: [
              AppButton(
                minimumSize: const Size.square(AppIconSize.tapTarget),
                onPressed: state.isSubmitting ? null : () => _close(state),
                child: Text(
                  'Close',
                  style: AppTypography.bodyMedium(
                    colors,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Create post',
                  textAlign: TextAlign.center,
                  style: AppTypography.title(colors),
                ),
              ),
              _PublishButton(
                enabled: state.canSubmit,
                submitting: state.isSubmitting,
                progress: state.uploadProgress,
                onPressed: _publish,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          _CreateTextField(
            key: const ValueKey<String>('create-post-body'),
            controller: _bodyController,
            focusNode: _bodyFocus,
            autofocus: true,
            label: 'Post text',
            placeholder: 'What would you like to share?',
            maxLength: 2000,
            maxLines: 6,
            minLines: 4,
            onChanged: cubit.bodyChanged,
          ),
          const SizedBox(height: AppSpacing.large),
          Text('Post type', style: AppTypography.bodyStrong(colors)),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              for (final type in PostType.values)
                _CreateChoice(
                  label: switch (type) {
                    PostType.general => 'General',
                    PostType.request => 'Request',
                    PostType.property => 'Property',
                  },
                  selected: state.postType == type,
                  onSelected: state.isSubmitting
                      ? null
                      : () => cubit.postTypeChanged(type),
                ),
            ],
          ),
          if (state.postType == PostType.request) ...[
            const SizedBox(height: AppSpacing.large),
            Text('Request type', style: AppTypography.bodyStrong(colors)),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                _CreateChoice(
                  label: 'Looking to buy',
                  selected: state.requestType == RequestType.lookingToBuy,
                  onSelected: state.isSubmitting
                      ? null
                      : () =>
                            cubit.requestTypeChanged(RequestType.lookingToBuy),
                ),
                _CreateChoice(
                  label: 'Looking to rent',
                  selected: state.requestType == RequestType.lookingToRent,
                  onSelected: state.isSubmitting
                      ? null
                      : () => cubit.requestTypeChanged(
                          RequestType.lookingToRent,
                        ),
                ),
              ],
            ),
          ],
          if (state.postType == PostType.property) ...[
            const SizedBox(height: AppSpacing.large),
            Text('Property status', style: AppTypography.bodyStrong(colors)),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              runSpacing: AppSpacing.small,
              children: [
                _CreateChoice(
                  label: 'For sale',
                  selected: state.propertyStatus == PropertyStatus.forSale,
                  onSelected: state.isSubmitting
                      ? null
                      : () => cubit.propertyStatusChanged(
                          PropertyStatus.forSale,
                        ),
                ),
                _CreateChoice(
                  label: 'For rent',
                  selected: state.propertyStatus == PropertyStatus.forRent,
                  onSelected: state.isSubmitting
                      ? null
                      : () => cubit.propertyStatusChanged(
                          PropertyStatus.forRent,
                        ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          _CreateTextField(
            key: const ValueKey<String>('create-post-location'),
            controller: _locationController,
            label: 'Location',
            placeholder: switch (state.postType) {
              PostType.general => 'Where is this relevant?',
              PostType.request => 'Where are you looking?',
              PostType.property => 'Where is the property?',
            },
            maxLength: 120,
            maxLines: 1,
            minLines: 1,
            onChanged: cubit.locationChanged,
          ),
          if (state.postType == PostType.property) ...[
            const SizedBox(height: AppSpacing.large),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Property images (${state.images.length}/4)',
                    style: AppTypography.bodyStrong(colors),
                  ),
                ),
                AppButton(
                  minimumSize: const Size(96, AppIconSize.tapTarget),
                  onPressed: state.isSubmitting || state.isPickingImages
                      ? null
                      : cubit.pickImages,
                  child: Text(
                    state.isPickingImages ? 'Opening…' : 'Add images',
                    style: AppTypography.bodyMedium(
                      colors,
                      color: colors.brandText,
                    ),
                  ),
                ),
              ],
            ),
            if (state.images.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.small),
              SizedBox(
                height: 136,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: state.images.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.small),
                  itemBuilder: (context, index) => SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: AppRadii.image,
                          child: Image.memory(
                            state.images[index].bytes,
                            key: ValueKey<String>(
                              'create-post-image-$index',
                            ),
                            width: 96,
                            height: 88,
                            cacheWidth:
                                (96 * MediaQuery.devicePixelRatioOf(context))
                                    .ceil(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.subtleSurface,
                              child: const SizedBox(width: 96, height: 88),
                            ),
                          ),
                        ),
                        AppButton(
                          minimumSize: const Size(96, 48),
                          onPressed: state.isSubmitting
                              ? null
                              : () => cubit.removeImage(index),
                          child: Text(
                            'Remove',
                            style: AppTypography.caption(
                              colors,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          if (state.failureMessage != null) ...[
            const SizedBox(height: AppSpacing.medium),
            Semantics(
              liveRegion: true,
              child: Text(
                state.failureMessage!,
                style: AppTypography.bodyMedium(
                  colors,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _publish() async {
    final post = await ref.read(createPostCubitProvider.bloc).submit();
    if (!mounted || post == null) return;
    setState(() => _discardApproved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context, post);
  }

  Future<void> _close(CreatePostState state) async {
    if (_askingDiscard || state.isSubmitting) return;
    if (!state.isPopulated || _discardApproved) {
      Navigator.pop(context);
      return;
    }
    _askingDiscard = true;
    final discard = await _confirmDiscard(context);
    _askingDiscard = false;
    if (!mounted || !discard) return;
    setState(() => _discardApproved = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context);
  }
}

Future<bool> _confirmDiscard(BuildContext context) async {
  if (context.isIos) {
    return await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) => CupertinoAlertDialog(
            title: const Text('Discard this post?'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep editing'),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}

final class _CreateTextField extends StatelessWidget {
  const _CreateTextField({
    required this.controller,
    required this.label,
    required this.placeholder,
    required this.maxLength,
    required this.maxLines,
    required this.minLines,
    required this.onChanged,
    super.key,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final String label;
  final String placeholder;
  final int maxLength;
  final int maxLines;
  final int minLines;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final field = context.isIos
        ? CupertinoTextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            maxLength: maxLength,
            maxLines: maxLines,
            minLines: minLines,
            placeholder: placeholder,
            style: AppTypography.body(colors),
            padding: const EdgeInsets.all(AppSpacing.medium),
            onChanged: onChanged,
          )
        : TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            maxLength: maxLength,
            maxLines: maxLines,
            minLines: minLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: placeholder,
              counterText: '',
              filled: true,
              fillColor: colors.subtleSurface,
              border: const OutlineInputBorder(
                borderRadius: AppRadii.image,
              ),
            ),
          );
    return Semantics(label: label, child: field);
  }
}

final class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    if (!context.isIos) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected == null ? null : (_) => onSelected!(),
      );
    }
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onSelected != null,
      label: label,
      onTap: onSelected,
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppIconSize.textButtonTapTarget),
        onPressed: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.brandTint : null,
            border: selected
                ? null
                : Border.all(
                    color: colors.textPrimary.withValues(alpha: 0.1),
                  ),
            borderRadius: AppRadii.pill,
          ),
          child: Text(
            label,
            style: AppTypography.caption(
              colors,
              color: selected ? colors.brandText : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

final class _PublishButton extends StatelessWidget {
  const _PublishButton({
    required this.enabled,
    required this.submitting,
    required this.progress,
    required this.onPressed,
  });

  final bool enabled;
  final bool submitting;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final child = submitting
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(
              value: progress > 0 && progress < 1 ? progress : null,
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colors.onBrand),
            ),
          )
        : const Text('Publish');
    return SizedBox(
      width: 88,
      height: AppIconSize.tapTarget,
      child: context.isIos
          ? CupertinoButton.filled(
              color: colors.brand,
              padding: EdgeInsets.zero,
              onPressed: enabled ? onPressed : null,
              child: DefaultTextStyle(
                style: AppTypography.bodyMedium(
                  colors,
                  color: colors.onBrand,
                ),
                child: child,
              ),
            )
          : FilledButton(
              onPressed: enabled ? onPressed : null,
              child: child,
            ),
    );
  }
}
