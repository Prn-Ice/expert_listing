/// Icon and interaction geometry for the Expert Listing design system.
library;

/// Visible glyph sizes measured in the Figma reference, and the minimum
/// semantic tap region every icon control must keep.
abstract final class AppIconSize {
  /// Engagement-row and metadata glyphs.
  static const double small = 16;

  /// Navigation, header action, and prominent control glyphs.
  static const double medium = 20;

  /// Large affordances such as the story add badge.
  static const double large = 24;

  /// Minimum hit region for any icon control, per the design contract.
  static const double tapTarget = 48;
}

/// The committed SVG icon inventory (Figma frame [private design node removed]; per-icon node IDs
/// are tracked in docs/wiki/design-system.md provenance).
abstract final class AppIcons {
  static const String _dir = 'assets/icons';

  /// Bookmark action.
  static const String bookmark = '$_dir/bookmark.svg';

  /// Comment action.
  static const String comment = '$_dir/comment.svg';

  /// Filters sheet affordance.
  static const String filter = '$_dir/filter.svg';

  /// Like action.
  static const String heart = '$_dir/heart.svg';

  /// Owned-location row.
  static const String mapPin = '$_dir/map-pin.svg';

  /// Messages preview boundary.
  static const String messages = '$_dir/messages.svg';

  /// Active feed destination.
  static const String navFeedActive = '$_dir/nav-feed-active.svg';

  /// List / create-post destination.
  static const String navList = '$_dir/nav-list.svg';

  /// Notifications preview boundary.
  static const String navNotifications = '$_dir/nav-notifications.svg';

  /// Profile preview boundary.
  static const String navProfile = '$_dir/nav-profile.svg';

  /// Post overflow menu.
  static const String postOverflow = '$_dir/post-overflow.svg';

  /// Share action.
  static const String share = '$_dir/share.svg';

  /// Your-story add badge.
  static const String storyAdd = '$_dir/story-add.svg';

  /// Request-type / property-status tag glyph.
  static const String transactionTag = '$_dir/transaction-tag.svg';
}
