import 'package:equatable/equatable.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// Renderable state for the independent property catalog.
final class ListingsState extends Equatable {
  /// Creates a property-catalog state.
  const ListingsState({
    this.listings = const [],
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
  });

  /// The initial untouched catalog state.
  static const initial = ListingsState();

  /// Property-only posts in server order.
  final List<PropertyFeedPost> listings;

  /// The opaque cursor for a later property page.
  final String? nextCursor;

  /// Whether no property content is ready yet.
  final bool isInitialLoading;

  /// Whether visible property content is refreshing.
  final bool isRefreshing;

  /// Whether a later cursor page is loading.
  final bool isLoadingMore;

  /// The actual source of the visible catalog data.
  final FeedDataSource source;

  /// When the visible saved page was persisted.
  final DateTime? savedAt;

  /// Why the repository used saved property data.
  final FeedFallbackReason? fallbackReason;

  /// A first-page failure with no visible content.
  final FeedLoadFailure? failure;

  /// Whether a refresh failed while cards remain visible.
  final bool refreshFailed;

  /// Whether the most recent cursor request failed.
  final bool nextPageFailed;

  /// Whether a later property page is available.
  bool get canLoadMore => nextCursor != null;

  /// Whether visible content must be labelled as saved.
  bool get isShowingSavedListings =>
      source == FeedDataSource.saved && !isInitialLoading && failure == null;

  /// Copies the visible catalog state with explicit nullable-field clearing.
  ListingsState copyWith({
    List<PropertyFeedPost>? listings,
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
  }) {
    return ListingsState(
      listings: listings ?? this.listings,
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
    );
  }

  @override
  List<Object?> get props => [
    listings,
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
  ];
}
