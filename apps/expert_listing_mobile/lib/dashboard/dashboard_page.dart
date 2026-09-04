import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:flutter/material.dart';

/// The app-level dashboard scaffold and active destination navigation.
class DashboardPage extends StatefulWidget {
  /// Creates the dashboard.
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

final class _DashboardPageState extends State<DashboardPage> {
  final _feedKey = GlobalKey<FeedViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FeedView(key: _feedKey),
      bottomNavigationBar: _DashboardNavigation(
        onFeedPressed: () => _feedKey.currentState?.returnToTopOrRefresh(),
        onNotice: (message) => AppNotice.show(context, message),
      ),
    );
  }
}

final class _DashboardNavigation extends StatelessWidget {
  const _DashboardNavigation({
    required this.onFeedPressed,
    required this.onNotice,
  });

  final VoidCallback onFeedPressed;
  final ValueChanged<String> onNotice;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
        color: colors.canvas,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navFeedActive,
                  label: 'Feed',
                  selected: true,
                  onPressed: onFeedPressed,
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.search,
                  label: 'Search',
                  onPressed: () => onNotice(
                    'Search is not part of this preview. Try Filters.',
                  ),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navList,
                  label: 'List',
                  onPressed: () => onNotice(
                    'Post creation is part of the next preview step.',
                  ),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navNotifications,
                  label: 'Notification',
                  onPressed: () =>
                      onNotice('Notifications are not part of this preview.'),
                ),
              ),
              Expanded(
                child: _NavigationItem(
                  icon: AppIcons.navProfile,
                  label: 'Profile',
                  onPressed: () =>
                      onNotice('Profiles are not part of this preview.'),
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
    final color = selected ? colors.brandText : colors.textTertiary;
    return Semantics(
      container: true,
      button: true,
      label: label,
      selected: selected,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox(
        height: 72,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: AppIconSize.large, color: color),
              const SizedBox(height: 2),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTypography.caption(colors, color: color),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
