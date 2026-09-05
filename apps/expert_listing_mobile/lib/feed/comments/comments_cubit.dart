// Private dependencies retain product-language argument names at call sites.
// ignore_for_file: prefer_initializing_formals

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';

part 'comments_state.dart';

/// Coordinates one post's flat persistent comment thread.
final class CommentsCubit extends Cubit<CommentsState> {
  /// Creates the comment state machine.
  CommentsCubit({
    required int postId,
    required FeedRepository repository,
    void Function()? onCommentAdded,
  }) : _onCommentAdded = onCommentAdded,
       _postId = postId,
       _repository = repository,
       super(CommentsState.initial);

  final int _postId;
  final FeedRepository _repository;
  final void Function()? _onCommentAdded;

  /// Loads comments once unless the user explicitly retries a failure.
  Future<void> load() async {
    if (state.isLoading || state.hasLoaded) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));
    try {
      final comments = await _repository.loadComments(_postId);
      if (isClosed) return;
      emit(
        state.copyWith(
          comments: comments,
          isLoading: false,
          hasLoaded: true,
          clearFailure: true,
        ),
      );
    } on Object {
      if (isClosed) return;
      emit(state.copyWith(isLoading: false, failure: CommentsFailure.load));
    }
  }

  /// Keeps the exact in-progress input in state across retries.
  void draftChanged(String value) {
    emit(state.copyWith(draft: value, clearFailure: true));
  }

  /// Persists the current draft and appends the server result.
  Future<bool> submit() async {
    final body = state.draft.trim();
    if (body.isEmpty ||
        body.runes.length > 1000 ||
        state.isLoading ||
        state.isSubmitting) {
      return false;
    }
    emit(state.copyWith(isSubmitting: true, clearFailure: true));
    try {
      final comment = await _repository.createComment(
        postId: _postId,
        body: body,
      );
      _onCommentAdded?.call();
      if (isClosed) return true;
      emit(
        state.copyWith(
          comments: [...state.comments, comment],
          draft: '',
          isSubmitting: false,
          hasLoaded: true,
          clearFailure: true,
        ),
      );
      return true;
    } on Object {
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSubmitting: false,
          failure: CommentsFailure.submit,
        ),
      );
      return false;
    }
  }

  /// Allows a failed initial list request to run again.
  Future<void> retry() async {
    if (state.isLoading) return;
    emit(state.copyWith(hasLoaded: false, clearFailure: true));
    await load();
  }
}
