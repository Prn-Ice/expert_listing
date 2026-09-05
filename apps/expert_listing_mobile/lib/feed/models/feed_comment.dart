// API-shaped fields are self-describing.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:expert_listing/feed/models/feed_post.dart';

/// One hydrated, persistent comment returned by Hono.
final class FeedComment extends Equatable {
  /// Creates a feed comment.
  const FeedComment({
    required this.id,
    required this.postId,
    required this.body,
    required this.createdAt,
    required this.author,
  });

  /// Parses the strict comment API shape.
  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final postId = json['postId'];
    final body = json['body'];
    final createdAt = json['createdAt'];
    final author = json['author'];
    final parsedDate = createdAt is String
        ? DateTime.tryParse(createdAt)
        : null;
    if (id is! int ||
        postId is! int ||
        body is! String ||
        parsedDate == null ||
        author is! Map<String, dynamic>) {
      throw const FormatException('Comment response is invalid.');
    }
    return FeedComment(
      id: id,
      postId: postId,
      body: body,
      createdAt: parsedDate.toUtc(),
      author: FeedAuthor.fromJson(author),
    );
  }

  final int id;
  final int postId;
  final String body;
  final DateTime createdAt;
  final FeedAuthor author;

  @override
  List<Object?> get props => [id, postId, body, createdAt, author];
}

/// The authoritative result of setting the current user's desired like state.
final class LikeResult extends Equatable {
  /// Creates a like result.
  const LikeResult({
    required this.postId,
    required this.liked,
    required this.likeCount,
  });

  /// Parses the strict like API shape.
  factory LikeResult.fromJson(Map<String, dynamic> json) {
    final postId = json['postId'];
    final liked = json['liked'];
    final likeCount = json['likeCount'];
    if (postId is! int || liked is! bool || likeCount is! int) {
      throw const FormatException('Like response is invalid.');
    }
    return LikeResult(postId: postId, liked: liked, likeCount: likeCount);
  }

  final int postId;
  final bool liked;
  final int likeCount;

  @override
  List<Object?> get props => [postId, liked, likeCount];
}

/// A safe engagement-boundary failure.
final class EngagementFailure implements Exception {
  /// Creates an engagement failure.
  const EngagementFailure();
}
