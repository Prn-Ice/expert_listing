import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/post_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('share text names the owned location and request subtype', () {
    final post = FeedPost.fromJson(const {
      ..._common,
      'postType': 'request',
      'request': {
        'type': 'looking_to_rent',
        'location': 'Yaba, Lagos',
      },
    });

    expect(
      postDetailsText(post),
      contains('Request: Looking to Rent\nLocation: Yaba, Lagos'),
    );
    expect(postDetailsText(post), isNot(contains('http')));
  });

  test('share text names property status without inventing a URL', () {
    final post = FeedPost.fromJson(const {
      ..._common,
      'postType': 'property',
      'property': {
        'id': 9,
        'status': 'for_sale',
        'location': 'Lekki, Lagos',
        'images': <Object>[],
      },
    });

    expect(
      postDetailsText(post),
      'Prince (@prince)\nProperty: For Sale\nLocation: Lekki, Lagos\n\n'
      'Inspection is open.',
    );
  });
}

const _common = <String, dynamic>{
  'id': 9,
  'body': 'Inspection is open.',
  'createdAt': '2026-09-05T12:00:00.000Z',
  'viewCount': 0,
  'bookmarkCount': 0,
  'likeCount': 0,
  'commentCount': 0,
  'likedByCurrentUser': false,
  'author': <String, dynamic>{
    'id': '11111111-1111-4111-8111-111111111111',
    'handle': 'prince',
    'displayName': 'Prince',
    'role': 'Buyer',
    'avatarUrl': null,
  },
};
