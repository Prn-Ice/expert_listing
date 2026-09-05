import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter/material.dart';

/// A property-first catalog card without social-feed chrome.
class ListingCard extends StatelessWidget {
  /// Creates a catalog card for one hydrated property post.
  const ListingCard({
    required this.listing,
    required this.onPressed,
    super.key,
  });

  /// The property post rendered by this card.
  final PropertyFeedPost listing;

  /// Handles the currently unavailable property-details boundary.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = listing.status == PropertyStatus.forSale
        ? ('For Sale', colors.info, colors.infoTint)
        : ('For Rent', colors.brandText, colors.brandTint);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListingMedia(
              key: ValueKey<String>('listing-media-${listing.propertyId}'),
              images: listing.images,
              location: listing.location,
            ),
            AppPressable(
              key: ValueKey<String>('listing-${listing.propertyId}'),
              onPressed: onPressed,
              borderRadius: AppRadii.card,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: status.$3,
                        borderRadius: AppRadii.pill,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.small,
                          vertical: AppSpacing.xsmall,
                        ),
                        child: Text(
                          status.$1,
                          style: AppTypography.caption(
                            colors,
                            color: status.$2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    Row(
                      children: [
                        AppIcon(
                          AppIcons.mapPin,
                          size: AppIconSize.small,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.xsmall),
                        Expanded(
                          child: Text(
                            listing.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title(colors),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.small),
                    Text(
                      listing.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        colors,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ListingMedia extends StatefulWidget {
  const _ListingMedia({
    required this.images,
    required this.location,
    super.key,
  });

  final List<PropertyImage> images;
  final String location;

  @override
  State<_ListingMedia> createState() => _ListingMediaState();
}

final class _ListingMediaState extends State<_ListingMedia> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final images = widget.images.where((image) => image.url != null).toList();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AspectRatio(
      aspectRatio: 388 / 260,
      child: ColoredBox(
        color: colors.brandTint,
        child: images.isEmpty
            ? Center(
                child: AppIcon(
                  AppIcons.mapPin,
                  size: AppIconSize.large,
                  color: colors.brandText,
                ),
              )
            : Stack(
                children: [
                  PageView.builder(
                    key: PageStorageKey<String>(
                      'listing-carousel-${images.first.id}',
                    ),
                    controller: _controller,
                    itemCount: images.length,
                    onPageChanged: (page) => setState(() => _page = page),
                    itemBuilder: (context, index) => AppNetworkImage(
                      imageUrl: images[index].url!,
                      semanticLabel:
                          '${widget.location}, photo '
                          '${index + 1} of ${images.length}',
                      placeholder: ColoredBox(color: colors.subtleSurface),
                      fallback: ColoredBox(
                        color: colors.subtleSurface,
                        child: Center(
                          child: AppIcon(
                            AppIcons.mapPin,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    Positioned(
                      right: AppSpacing.medium,
                      bottom: AppSpacing.medium,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.56),
                          borderRadius: AppRadii.pill,
                        ),
                        child: AnimatedSize(
                          duration: reducedMotion
                              ? Duration.zero
                              : AppMotion.fast,
                          curve: AppMotion.curve,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.small,
                              vertical: AppSpacing.xsmall,
                            ),
                            child: Text(
                              '${_page + 1} / ${images.length}',
                              style: AppTypography.caption(
                                colors,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (images.length > 1) ...[
                    _pageControl(
                      alignment: Alignment.centerLeft,
                      label: 'Previous photo',
                      icon: Icons.chevron_left,
                      onPressed: _page == 0 ? null : () => _showPage(_page - 1),
                    ),
                    _pageControl(
                      alignment: Alignment.centerRight,
                      label: 'Next photo',
                      icon: Icons.chevron_right,
                      onPressed: _page == images.length - 1
                          ? null
                          : () => _showPage(_page + 1),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _pageControl({
    required Alignment alignment,
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
        child: AppPressable(
          semanticLabel: label,
          color: Colors.black54,
          borderRadius: AppRadii.pill,
          onPressed: onPressed,
          child: SizedBox.square(
            dimension: AppIconSize.tapTarget,
            child: Icon(
              icon,
              color: onPressed == null ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  void _showPage(int page) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.jumpToPage(page);
      return;
    }
    _controller.animateToPage(
      page,
      duration: AppMotion.medium,
      curve: AppMotion.curve,
    );
  }
}
