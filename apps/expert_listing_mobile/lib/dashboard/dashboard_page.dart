import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/app/preview_actor.dart';
import 'package:expert_listing/dashboard/destination_switcher.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:expert_listing/listings/view/listings_view.dart';
import 'package:expert_listing/notifications/view/notifications_view.dart';
import 'package:expert_listing/profile/view/profile_view.dart';
import 'package:expert_listing/search/view/search_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app-level dashboard scaffold and active destination navigation.
class DashboardPage extends ConsumerStatefulWidget {
  /// Creates the dashboard.
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

final class _DashboardPageState extends ConsumerState<DashboardPage> {
  final _feedKey = GlobalKey<FeedViewState>();
  final _feedScrollController = ScrollController();
  _DashboardDestination _selectedDestination = _DashboardDestination.feed;

  @override
  void dispose() {
    _feedScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewActor = ref.watch(previewActorProvider);
    return PrimaryScrollController(
      controller: _feedScrollController,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).appBarTheme.systemOverlayStyle!,
        child: AppScaffold(
          body: DestinationSwitcher(
            key: ValueKey<String?>('dashboard-actor-$previewActor'),
            selectedIndex: _selectedDestination.index,
            children: [
              FeedView(
                key: _feedKey,
                scrollController: _feedScrollController,
              ),
              SearchView(
                isActive: _selectedDestination == _DashboardDestination.search,
                onPropertySelected: (_) => AppNotice.show(
                  context,
                  'Property details aren’t part of this preview.',
                ),
              ),
              ListingsView(
                isActive:
                    _selectedDestination == _DashboardDestination.listings,
                onListingPressed: () => AppNotice.show(
                  context,
                  'Property details aren’t part of this preview.',
                ),
              ),
              NotificationsView(
                isActive:
                    _selectedDestination == _DashboardDestination.notifications,
              ),
              ProfileView(
                isActive: _selectedDestination == _DashboardDestination.profile,
              ),
            ],
          ),
          bottomNavigationBar: _DashboardNavigation(
            selectedDestination: _selectedDestination,
            onFeedPressed: _selectFeed,
            onSearchPressed: () => setState(
              () => _selectedDestination = _DashboardDestination.search,
            ),
            onListingsPressed: () => setState(
              () => _selectedDestination = _DashboardDestination.listings,
            ),
            onNotificationsPressed: () => setState(
              () => _selectedDestination = _DashboardDestination.notifications,
            ),
            onProfilePressed: () => setState(
              () => _selectedDestination = _DashboardDestination.profile,
            ),
          ),
        ),
      ),
    );
  }

  void _selectFeed() {
    if (_selectedDestination == _DashboardDestination.feed) {
      _feedKey.currentState?.returnToTopOrRefresh();
      return;
    }
    setState(() => _selectedDestination = _DashboardDestination.feed);
  }
}

enum _DashboardDestination { feed, search, listings, notifications, profile }

final class _DashboardNavigation extends StatelessWidget {
  const _DashboardNavigation({
    required this.selectedDestination,
    required this.onFeedPressed,
    required this.onSearchPressed,
    required this.onListingsPressed,
    required this.onNotificationsPressed,
    required this.onProfilePressed,
  });

  final _DashboardDestination selectedDestination;
  final VoidCallback onFeedPressed;
  final VoidCallback onSearchPressed;
  final VoidCallback onListingsPressed;
  final VoidCallback onNotificationsPressed;
  final VoidCallback onProfilePressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // The Figma Nav frame ([private design node removed]) draws a 0.5px --border2 top hairline.
        border: Border(top: BorderSide(color: colors.border, width: 0.5)),
        color: colors.canvas,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xlarge,
            AppSpacing.large,
            AppSpacing.xlarge,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navFeedActive,
                  label: 'Feed',
                  selected: selectedDestination == _DashboardDestination.feed,
                  onPressed: onFeedPressed,
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.search,
                  label: 'Search',
                  selected: selectedDestination == _DashboardDestination.search,
                  onPressed: onSearchPressed,
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navList,
                  label: 'List',
                  selected:
                      selectedDestination == _DashboardDestination.listings,
                  onPressed: onListingsPressed,
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navNotifications,
                  label: 'Notification',
                  selected:
                      selectedDestination ==
                      _DashboardDestination.notifications,
                  onPressed: onNotificationsPressed,
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navProfile,
                  label: 'Profile',
                  selected:
                      selectedDestination == _DashboardDestination.profile,
                  onPressed: onProfilePressed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String icon;
  final String label;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = selected ? colors.brandText : colors.textSecondary;
    return AppPressable(
      // Green marks selection, never press feedback. iOS answers with the
      // restrained press opacity; Android with a neutral ink contained to
      // the destination cell, so it never crosses a divider or neighbour.
      onPressed: onPressed,
      borderRadius: AppRadii.pill,
      overlayColor: colors.subtleSurface,
      semanticLabel: label,
      selected: selected,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppIconSize.large, color: color),
          // The Figma Nav containers ([private design node removed]) gap 11px between the
          // 24px glyph and its 14px label.
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: selected
                    ? AppTypography.navLabelSelected(colors, color: color)
                    : AppTypography.navLabel(colors, color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
