// Event fields are named directly after the user action they carry.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// User and lifecycle events that can overlap in the feed.
sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the active filter for the first time.
final class FeedStarted extends FeedEvent {
  const FeedStarted();
}

/// Refreshes the active first page while preserving visible content.
final class FeedRefreshed extends FeedEvent {
  const FeedRefreshed();
}

/// Replaces the feed with a new active server filter set.
final class FeedFiltersApplied extends FeedEvent {
  const FeedFiltersApplied(this.filter);

  final FeedFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Restores the unfiltered feed.
final class FeedFiltersCleared extends FeedEvent {
  const FeedFiltersCleared();
}

/// Attempts the next cursor page once.
final class FeedNextPageRequested extends FeedEvent {
  const FeedNextPageRequested();
}

/// Retries the active first page after a failure or saved fallback.
final class FeedRetryRequested extends FeedEvent {
  const FeedRetryRequested();
}

/// Optimistically reverses the current like intent for one post.
final class FeedLikeToggled extends FeedEvent {
  const FeedLikeToggled(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

/// Reverses the device-only bookmark state for one post.
final class FeedBookmarkToggled extends FeedEvent {
  const FeedBookmarkToggled(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

/// Hides one post until this feed lifecycle ends.
final class FeedPostHidden extends FeedEvent {
  const FeedPostHidden(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

/// Restores one session-hidden post.
final class FeedPostRestored extends FeedEvent {
  const FeedPostRestored(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

/// Reconciles a newly persisted comment into the visible feed count.
final class FeedCommentAdded extends FeedEvent {
  const FeedCommentAdded(this.postId);

  final int postId;

  @override
  List<Object?> get props => [postId];
}

/// Inserts a successfully-created hydrated post without reloading the feed.
final class FeedPostCreated extends FeedEvent {
  const FeedPostCreated(this.post);

  final FeedPost post;

  @override
  List<Object?> get props => [post];
}
