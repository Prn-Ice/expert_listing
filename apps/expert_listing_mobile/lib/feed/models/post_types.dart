// Server-defined post and subtype discriminators shared by feed data and
// filters.
// ignore_for_file: public_member_api_docs

/// Server-side choices for the feed's discriminated post types.
enum PostType {
  general,
  request,
  property;

  /// The value accepted by the Hono API.
  String get wireValue => name;
}

/// Server-side choices available only while filtering request posts.
enum RequestType {
  lookingToBuy('looking_to_buy'),
  lookingToRent('looking_to_rent');

  const RequestType(this.wireValue);

  /// The value accepted by the Hono API.
  final String wireValue;
}

/// Server-side choices available only while filtering property posts.
enum PropertyStatus {
  forSale('for_sale'),
  forRent('for_rent');

  const PropertyStatus(this.wireValue);

  /// The value accepted by the Hono API.
  final String wireValue;
}
