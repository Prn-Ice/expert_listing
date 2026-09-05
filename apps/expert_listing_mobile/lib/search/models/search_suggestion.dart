// API-shaped fields are self-describing and parsed strictly.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';
import 'package:expert_listing/feed/models/post_types.dart';

sealed class SearchSuggestion extends Equatable {
  const SearchSuggestion();

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) {
    return switch (_string(json, 'type')) {
      'location' => LocationSearchSuggestion(
        label: _string(json, 'label'),
        propertyCount: _int(json, 'propertyCount'),
      ),
      'property' => PropertySearchSuggestion(
        postId: _int(json, 'postId'),
        propertyId: _int(json, 'propertyId'),
        status: switch (_string(json, 'status')) {
          'for_sale' => PropertyStatus.forSale,
          'for_rent' => PropertyStatus.forRent,
          _ => throw const FormatException(
            'Search property has an unknown status.',
          ),
        },
        location: _string(json, 'location'),
        summary: _string(json, 'summary'),
        imageUrl: _optionalString(json, 'imageUrl'),
      ),
      _ => throw const FormatException(
        'Search suggestion has an unknown type.',
      ),
    };
  }
}

final class LocationSearchSuggestion extends SearchSuggestion {
  const LocationSearchSuggestion({
    required this.label,
    required this.propertyCount,
  });

  final String label;
  final int propertyCount;

  @override
  List<Object?> get props => [label, propertyCount];
}

final class PropertySearchSuggestion extends SearchSuggestion {
  const PropertySearchSuggestion({
    required this.postId,
    required this.propertyId,
    required this.status,
    required this.location,
    required this.summary,
    required this.imageUrl,
  });

  final int postId;
  final int propertyId;
  final PropertyStatus status;
  final String location;
  final String summary;
  final String? imageUrl;

  @override
  List<Object?> get props => [
    postId,
    propertyId,
    status,
    location,
    summary,
    imageUrl,
  ];
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Search response has an invalid $key value.');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('Search response has an invalid $key value.');
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Search response has an invalid $key value.');
}
