import 'package:equatable/equatable.dart';
import 'package:expert_listing/feed/models/post_types.dart';

/// One applied server-side feed filter set.
final class FeedFilter extends Equatable {
  /// Creates a filter set. Subtype filters are meaningful only for their
  /// matching [postType] and are validated by the API as well.
  const FeedFilter({
    this.postType,
    this.requestType,
    this.propertyStatus,
    this.location,
  });

  /// Restricts the feed to one discriminated post type.
  final PostType? postType;

  /// Restricts request posts to one request type.
  final RequestType? requestType;

  /// Restricts property posts to one listing status.
  final PropertyStatus? propertyStatus;

  /// Restricts matching owned locations to a literal substring.
  final String? location;

  /// Whether no server filters are active.
  bool get isEmpty => activeCount == 0;

  /// The count shown on the closed filter control.
  int get activeCount {
    var count = 0;
    if (postType != null) count++;
    if (requestType != null) count++;
    if (propertyStatus != null) count++;
    if (location?.trim().isNotEmpty ?? false) count++;
    return count;
  }

  /// Serializes only valid, active API query parameters.
  Map<String, String> toQueryParameters() {
    final query = <String, String>{};
    if (postType != null) query['postType'] = postType!.wireValue;
    if (requestType != null) query['requestType'] = requestType!.wireValue;
    if (propertyStatus != null) {
      query['propertyStatus'] = propertyStatus!.wireValue;
    }

    final trimmedLocation = location?.trim();
    if (trimmedLocation?.isNotEmpty ?? false) {
      query['location'] = trimmedLocation!;
    }
    return query;
  }

  @override
  List<Object?> get props => [postType, requestType, propertyStatus, location];
}
