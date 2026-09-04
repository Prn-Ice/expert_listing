// Event fields are named directly after the user action they carry.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

import 'package:expert_listing/feed/models/feed_filter.dart';

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
