import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/comments/comments_cubit.dart';
import 'package:expert_listing/feed/feed_providers.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single comments surface used by every comment entry point.
class CommentsSheet extends ConsumerStatefulWidget {
  /// Creates a comments sheet for [postId].
  const CommentsSheet({
    required this.postId,
    super.key,
  });

  /// The post whose thread is displayed.
  final int postId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

final class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(
      () {
        if (mounted) {
          unawaited(
            ref.read(commentsCubitProvider(widget.postId).bloc).load(),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = commentsCubitProvider(widget.postId);
    final state = ref.watch(provider);
    final cubit = ref.read(provider.bloc);
    final colors = AppColors.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xlarge,
            AppSpacing.small,
            AppSpacing.small,
            AppSpacing.xsmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Comments', style: AppTypography.title(colors)),
              ),
              _CloseAction(
                onPressed: () => Navigator.of(
                  context,
                  rootNavigator: true,
                ).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _CommentList(state: state, onRetry: cubit.retry),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xlarge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.failure == CommentsFailure.submit) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      "Couldn't add your comment. It's still here.",
                      key: const ValueKey<String>('comment-submit-failure'),
                      style: AppTypography.caption(
                        colors,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.small),
                ],
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CommentInput(
                          controller: _controller,
                          enabled: !state.isSubmitting,
                          onChanged: cubit.draftChanged,
                          onSubmitted: () => _submit(cubit),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.small),
                      _SubmitButton(
                        onPressed:
                            state.isLoading ||
                                state.isSubmitting ||
                                state.draft.trim().isEmpty
                            ? null
                            : () => _submit(cubit),
                        isSubmitting: state.isSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (context.isIos) return content;
    return FractionallySizedBox(heightFactor: 0.72, child: content);
  }

  Future<void> _submit(CommentsCubit cubit) async {
    final added = await cubit.submit();
    if (!mounted || !added) return;
    _controller.clear();
  }
}

final class _CloseAction extends StatelessWidget {
  const _CloseAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!context.isIos) return CloseButton(onPressed: onPressed);
    return Semantics(
      button: true,
      label: 'Close',
      excludeSemantics: true,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppIconSize.tapTarget),
        onPressed: onPressed,
        child: Text(
          'Close',
          style: AppTypography.bodyMedium(
            AppColors.of(context),
            color: AppColors.of(context).brandText,
          ),
        ),
      ),
    );
  }
}

final class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (context.isIos) {
      final colors = AppColors.of(context);
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppIconSize.tapTarget),
        child: CupertinoTextField(
          key: const ValueKey<String>('comment-input'),
          controller: controller,
          enabled: enabled,
          minLines: 1,
          maxLines: 4,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          placeholder: 'Add a comment',
          style: AppTypography.body(colors),
          placeholderStyle: AppTypography.body(
            colors,
            color: colors.textTertiary,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.medium,
            vertical: AppSpacing.small,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: AppRadii.image,
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
        ),
      );
    }
    return TextField(
      key: const ValueKey<String>('comment-input'),
      controller: controller,
      enabled: enabled,
      minLines: 1,
      maxLines: 4,
      maxLength: 1000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        hintText: 'Add a comment',
        counterText: '',
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

final class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed, required this.isSubmitting});

  final VoidCallback? onPressed;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    if (!context.isIos) {
      return FilledButton(
        key: const ValueKey<String>('comment-submit'),
        onPressed: onPressed,
        child: isSubmitting
            ? const SizedBox.square(
                dimension: AppIconSize.small,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            : const Text('Post'),
      );
    }
    final colors = AppColors.of(context);
    return CupertinoButton(
      key: const ValueKey<String>('comment-submit'),
      color: colors.brand,
      minimumSize: const Size(64, AppIconSize.tapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.medium),
      onPressed: onPressed,
      child: isSubmitting
          ? CupertinoActivityIndicator(color: colors.onBrand)
          : Text(
              'Post',
              style: AppTypography.bodyMedium(colors, color: colors.onBrand),
            ),
    );
  }
}

final class _CommentList extends StatelessWidget {
  const _CommentList({required this.state, required this.onRetry});

  final CommentsState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.comments.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (state.failure == CommentsFailure.load && state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load comments."),
            const SizedBox(height: AppSpacing.small),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (state.comments.isEmpty) {
      return const Center(child: Text('No comments yet.'));
    }
    return ListView.separated(
      primary: true,
      padding: const EdgeInsets.all(AppSpacing.xlarge),
      itemCount: state.comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.large),
      itemBuilder: (context, index) => _CommentRow(
        key: ValueKey<int>(state.comments[index].id),
        comment: state.comments[index],
      ),
    );
  }
}

final class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, super.key});

  final FeedComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppAvatar(
          imageUrl: comment.author.avatarUrl,
          displayName: comment.author.displayName,
        ),
        const SizedBox(width: AppSpacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.author.displayName,
                style: AppTypography.title(colors),
              ),
              const SizedBox(height: AppSpacing.xsmall),
              Text(comment.body, style: AppTypography.body(colors)),
            ],
          ),
        ),
      ],
    );
  }
}
