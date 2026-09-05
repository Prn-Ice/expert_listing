import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';

/// Builds the truthful plain-text representation used by copy and native share.
String postDetailsText(FeedPost post) {
  final kind = switch (post) {
    RequestFeedPost(requestType: RequestType.lookingToBuy) =>
      'Request: Looking to Buy',
    RequestFeedPost(requestType: RequestType.lookingToRent) =>
      'Request: Looking to Rent',
    PropertyFeedPost(status: PropertyStatus.forSale) => 'Property: For Sale',
    PropertyFeedPost(status: PropertyStatus.forRent) => 'Property: For Rent',
    GeneralFeedPost() => 'General post',
  };
  return '${post.author.displayName} (@${post.author.handle})\n'
      '$kind\n'
      'Location: ${post.location}\n\n'
      '${post.body}';
}
