// API-shaped fields are self-describing; constructor order follows parse flow.
// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'package:equatable/equatable.dart';

import 'package:expert_listing/feed/models/feed_post.dart';

/// The origin of content rendered in the feed.
enum FeedDataSource { network, saved }

/// The failure category that permitted a saved-feed fallback.
enum FeedFallbackReason { connection, service }

/// Categories needed by the feed's honest unavailable-state UI.
enum FeedFailureKind { connection, service, unavailable }

/// A safe loading failure that preserves whether saved fallback was valid.
final class FeedLoadFailure implements Exception {
  /// Creates a classified feed loading failure.
  const FeedLoadFailure(this.kind);

  /// The visible failure category.
  final FeedFailureKind kind;
}

/// One paginated feed load with its honest provenance.
final class FeedLoadResult extends Equatable {
  /// Creates a loaded page of posts.
  const FeedLoadResult({
    required this.posts,
    required this.nextCursor,
    required this.source,
    this.savedAt,
    this.fallbackReason,
  });

  final List<FeedPost> posts;
  final String? nextCursor;
  final FeedDataSource source;
  final DateTime? savedAt;
  final FeedFallbackReason? fallbackReason;

  /// Parses the Hono `GET /posts` response.
  factory FeedLoadResult.fromJson(
    Map<String, dynamic> json, {
    required FeedDataSource source,
    DateTime? savedAt,
    FeedFallbackReason? fallbackReason,
  }) {
    final rawPosts = json['posts'];
    if (rawPosts is! List) {
      throw const FormatException('Feed response has invalid posts.');
    }
    final posts = rawPosts.map((post) {
      if (post is! Map<String, dynamic>) {
        throw const FormatException('Feed response has an invalid post.');
      }
      return FeedPost.fromJson(post);
    }).toList();

    final nextCursor = json['nextCursor'];
    if (nextCursor != null && nextCursor is! String) {
      throw const FormatException('Feed response has an invalid cursor.');
    }

    return FeedLoadResult(
      posts: posts,
      nextCursor: nextCursor as String?,
      source: source,
      savedAt: savedAt,
      fallbackReason: fallbackReason,
    );
  }

  @override
  List<Object?> get props => [
    posts,
    nextCursor,
    source,
    savedAt,
    fallbackReason,
  ];
}
