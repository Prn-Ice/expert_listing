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

  /// Minimum hit region for any text button control.
  static const double textButtonTapTarget = 32;
}

/// The committed SVG icon inventory.
abstract final class AppIcons {
  static const String _dir = 'assets/icons';

  /// Bookmark action.
  static const String bookmark = '$_dir/bookmark.svg';

  /// Selected bookmark action.
  static const String bookmarkFilled = '$_dir/bookmark-filled.svg';

  /// Comment action.
  static const String comment = '$_dir/comment.svg';

  /// Filters sheet affordance.
  static const String filter = '$_dir/filter.svg';

  /// Like action.
  static const String heart = '$_dir/heart.svg';

  /// Selected like action.
  static const String heartFilled = '$_dir/heart-filled.svg';

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

  /// Search preview boundary.
  static const String search = '$_dir/search.svg';

  /// Post overflow menu.
  static const String postOverflow = '$_dir/post-overflow.svg';

  /// Share action.
  static const String share = '$_dir/share.svg';

  /// Your-story add badge.
  static const String storyAdd = '$_dir/story-add.svg';

  /// The blue For Sale tag glyph.
  ///
  /// The four status glyphs are exact 4x Figma exports rasterized at 48px
  /// because no complete vector export is obtainable for these components.
  static const String postTag = '$_dir/for-sale.png';

  /// The purple Looking to Buy tag glyph.
  static const String lookingToBuyTag = '$_dir/looking-to-buy.png';

  /// The green For Rent key glyph.
  static const String propertyRentKey = '$_dir/for-rent.png';

  /// The amber Looking to Rent key glyph.
  static const String lookingToRentKey = '$_dir/looking-to-rent.png';
}
