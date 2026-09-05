import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/feed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: AppScaffold(
        body: FeedView(key: _feedKey),
        bottomNavigationBar: _DashboardNavigation(
          onFeedPressed: () => _feedKey.currentState?.returnToTopOrRefresh(),
          onNotice: (message) => AppNotice.show(context, message),
        ),
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
