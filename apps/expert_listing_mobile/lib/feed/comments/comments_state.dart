part of 'comments_cubit.dart';

// State fields directly describe the comment sheet's renderable condition.
// ignore_for_file: public_member_api_docs

enum CommentsFailure { load, submit }

final class CommentsState extends Equatable {
  const CommentsState({
    this.comments = const [],
    this.draft = '',
    this.isLoading = false,
    this.isSubmitting = false,
    this.hasLoaded = false,
    this.failure,
  });

  static const initial = CommentsState();

  final List<FeedComment> comments;
  final String draft;
  final bool isLoading;
  final bool isSubmitting;
  final bool hasLoaded;
  final CommentsFailure? failure;

  CommentsState copyWith({
    List<FeedComment>? comments,
    String? draft,
    bool? isLoading,
    bool? isSubmitting,
    bool? hasLoaded,
    CommentsFailure? failure,
    bool clearFailure = false,
  }) => CommentsState(
    comments: comments ?? this.comments,
    draft: draft ?? this.draft,
    isLoading: isLoading ?? this.isLoading,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [
    comments,
    draft,
    isLoading,
    isSubmitting,
    hasLoaded,
    failure,
  ];
}
