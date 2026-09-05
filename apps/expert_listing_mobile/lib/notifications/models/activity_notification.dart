// API-shaped fields are self-describing.
// ignore_for_file: public_member_api_docs

import 'package:equatable/equatable.dart';

final class ActivityActor extends Equatable {
  const ActivityActor({
    required this.handle,
    required this.displayName,
    required this.role,
    required this.avatarUrl,
  });

  factory ActivityActor.fromJson(Map<String, dynamic> json) {
    final handle = json['handle'];
    final displayName = json['displayName'];
    final role = json['role'];
    final avatarUrl = json['avatarUrl'];
    if (handle is! String ||
        handle.isEmpty ||
        displayName is! String ||
        displayName.isEmpty ||
        role is! String ||
        role.isEmpty ||
        (avatarUrl != null && avatarUrl is! String)) {
      throw const FormatException('Notification actor is invalid.');
    }
    return ActivityActor(
      handle: handle,
      displayName: displayName,
      role: role,
      avatarUrl: avatarUrl as String?,
    );
  }

  final String handle;
  final String displayName;
  final String role;
  final String? avatarUrl;

  @override
  List<Object?> get props => [handle, displayName, role, avatarUrl];
}

final class ActivityPost extends Equatable {
  const ActivityPost({required this.id, required this.body});

  factory ActivityPost.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final body = json['body'];
    if (id is! int || id < 1 || body is! String || body.isEmpty) {
      throw const FormatException('Notification post is invalid.');
    }
    return ActivityPost(id: id, body: body);
  }

  final int id;
  final String body;

  @override
  List<Object?> get props => [id, body];
}

/// One durable activity event addressed to the current server-resolved actor.
final class ActivityNotification extends Equatable {
  /// Creates an activity event.
  const ActivityNotification({
    required this.id,
    required this.createdAt,
    required this.readAt,
    required this.actor,
    required this.post,
  });

  /// Parses the supported like-activity DTO without accepting identity fields.
  factory ActivityNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final createdAt = _date(json['createdAt']);
    final rawReadAt = json['readAt'];
    final readAt = rawReadAt == null ? null : _date(rawReadAt);
    final actor = json['actor'];
    final post = json['post'];
    if (id is! int ||
        id < 1 ||
        type != 'postLike' ||
        createdAt == null ||
        (rawReadAt != null && readAt == null) ||
        (readAt != null && readAt.isBefore(createdAt)) ||
        actor is! Map<String, dynamic> ||
        post is! Map<String, dynamic>) {
      throw const FormatException('Notification response is invalid.');
    }
    return ActivityNotification(
      id: id,
      createdAt: createdAt,
      readAt: readAt,
      actor: ActivityActor.fromJson(actor),
      post: ActivityPost.fromJson(post),
    );
  }

  final int id;
  final DateTime createdAt;
  final DateTime? readAt;
  final ActivityActor actor;
  final ActivityPost post;

  bool get isRead => readAt != null;

  ActivityNotification markRead(DateTime value) => ActivityNotification(
    id: id,
    createdAt: createdAt,
    readAt: value,
    actor: actor,
    post: post,
  );

  @override
  List<Object?> get props => [id, createdAt, readAt, actor, post];
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}
