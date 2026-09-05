// State fields are named directly after the renderable feed condition.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// Renderable state for the network-first feed.
final class FeedState extends Equatable {
  /// Creates the state owned by the feed behavior layer.
  const FeedState({
    this.posts = const [],
    this.filter = const FeedFilter(),
    this.nextCursor,
    this.isInitialLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.source = FeedDataSource.network,
    this.savedAt,
    this.fallbackReason,
    this.failure,
    this.refreshFailed = false,
    this.nextPageFailed = false,
    this.bookmarkedPostIds = const {},
    this.hiddenPostIds = const {},
    this.noticeSequence = 0,
    this.notice,
  });

  /// The initial, untouched feed state.
  static const initial = FeedState();

  final List<FeedPost> posts;
  final FeedFilter filter;
  final String? nextCursor;
  final bool isInitialLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final FeedDataSource source;
  final DateTime? savedAt;
  final FeedFallbackReason? fallbackReason;
  final FeedLoadFailure? failure;
  final bool refreshFailed;
  final bool nextPageFailed;
  final Set<int> bookmarkedPostIds;
  final Set<int> hiddenPostIds;
  final int noticeSequence;
  final String? notice;

  /// Whether a later cursor request remains available.
  bool get canLoadMore => nextCursor != null;

  /// Whether saved content must remain visibly labelled.
  bool get isShowingSavedPosts =>
      source == FeedDataSource.saved && !isInitialLoading && failure == null;

  /// Posts remaining after session-only hides.
  List<FeedPost> get visiblePosts => posts
      .where((post) => !hiddenPostIds.contains(post.id))
      .toList(growable: false);

  /// Preserves state immutably while allowing explicit provenance clearing.
  FeedState copyWith({
    List<FeedPost>? posts,
    FeedFilter? filter,
    String? nextCursor,
    bool clearNextCursor = false,
    bool? isInitialLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    FeedDataSource? source,
    DateTime? savedAt,
    FeedFallbackReason? fallbackReason,
    bool clearSavedProvenance = false,
    FeedLoadFailure? failure,
    bool clearFailure = false,
    bool? refreshFailed,
    bool? nextPageFailed,
    Set<int>? bookmarkedPostIds,
    Set<int>? hiddenPostIds,
    int? noticeSequence,
    String? notice,
    bool clearNotice = false,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      filter: filter ?? this.filter,
      nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      source: source ?? this.source,
      savedAt: clearSavedProvenance ? null : savedAt ?? this.savedAt,
      fallbackReason: clearSavedProvenance
          ? null
          : fallbackReason ?? this.fallbackReason,
      failure: clearFailure ? null : failure ?? this.failure,
      refreshFailed: refreshFailed ?? this.refreshFailed,
      nextPageFailed: nextPageFailed ?? this.nextPageFailed,
      bookmarkedPostIds: bookmarkedPostIds ?? this.bookmarkedPostIds,
      hiddenPostIds: hiddenPostIds ?? this.hiddenPostIds,
      noticeSequence: noticeSequence ?? this.noticeSequence,
      notice: clearNotice ? null : notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    posts,
    filter,
    nextCursor,
    isInitialLoading,
    isRefreshing,
    isLoadingMore,
    source,
    savedAt,
    fallbackReason,
    failure,
    refreshFailed,
    nextPageFailed,
    bookmarkedPostIds,
    hiddenPostIds,
    noticeSequence,
    notice,
  ];
}
