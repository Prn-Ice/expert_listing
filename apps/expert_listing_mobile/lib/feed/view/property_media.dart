import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Property imagery, paging, and full-screen viewing for a feed post.
class PropertyMedia extends StatefulWidget {
  /// Creates property media from the post's ordered images.
  const PropertyMedia({required this.images, super.key});

  /// Images in their server-provided display order.
  final List<PropertyImage> images;

  @override
  State<PropertyMedia> createState() => _PropertyMediaState();
}

final class _PropertyMediaState extends State<PropertyMedia> {
  var _page = 0;
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final restoredPage = _controller.page?.round() ?? 0;
      if (restoredPage != _page) setState(() => _page = restoredPage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images.where((image) => image.url != null).toList();
    if (images.isEmpty) return const SizedBox.shrink();
    final reducedMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final indicatorDuration = reducedMotion ? Duration.zero : AppMotion.medium;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Figma's property media box is 388 by 260 at the reference width.
        final height = constraints.maxWidth * 260 / 388;
        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: AppRadii.image,
            child: Stack(
              children: [
                PageView.builder(
                  key: PageStorageKey<String>(
                    'property-media-${images.first.id}',
                  ),
                  controller: _controller,
                  itemCount: images.length,
                  onPageChanged: (page) => setState(() => _page = page),
                  itemBuilder: (context, index) {
                    final image = images[index];
                    return AppPressable(
                      onPressed: () => _showImage(
                        context,
                        images,
                        initialIndex: index,
                      ),
                      child: AppNetworkImage(
                        imageUrl: image.url!,
                        semanticLabel:
                            'Property photo ${index + 1} of ${images.length}',
                        placeholder: ColoredBox(
                          color: AppColors.of(context).surface,
                        ),
                        fallback: ColoredBox(
                          color: AppColors.of(context).surface,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (images.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: DecoratedBox(
                        key: ValueKey<String>(
                          'property-media-${images.first.id}-indicators',
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              images.length,
                              (index) => AnimatedContainer(
                                key: ValueKey<String>(
                                  'property-media-${images.first.id}'
                                  '-indicator-$index',
                                ),
                                duration: indicatorDuration,
                                curve: AppMotion.curve,
                                width: index == _page ? 14 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: index == _page ? 1 : 0.62,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImage(
    BuildContext context,
    List<PropertyImage> images, {
    required int initialIndex,
  }) {
    Widget buildViewer(BuildContext context) => _FullScreenImageViewer(
      images: images,
      initialIndex: initialIndex,
    );

    final route = context.isIos
        ? CupertinoPageRoute<void>(builder: buildViewer)
        : MaterialPageRoute<void>(builder: buildViewer);
    Navigator.of(context).push<void>(route);
  }
}

final class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  final List<PropertyImage> images;
  final int initialIndex;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

final class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late final List<TransformationController> _imageControllers;
  late int _page = widget.initialIndex;
  var _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _imageControllers = List.generate(
      widget.images.length,
      (index) =>
          TransformationController()..addListener(() => _zoomChanged(index)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    for (final controller in _imageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = widget.images.length;
    const overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          systemOverlayStyle: overlayStyle,
        ),
        body: Stack(
          children: [
            PageView.builder(
              key: const ValueKey<String>('full-screen-property-images'),
              controller: _controller,
              physics: _isZoomed ? const NeverScrollableScrollPhysics() : null,
              itemCount: imageCount,
              onPageChanged: (page) {
                _resetZoom(_page);
                setState(() => _page = page);
              },
              itemBuilder: (context, index) {
                final image = widget.images[index];
                var doubleTapPosition = Offset.zero;
                return GestureDetector(
                  onDoubleTapDown: (details) {
                    doubleTapPosition = details.localPosition;
                  },
                  onDoubleTap: () => _toggleZoom(index, doubleTapPosition),
                  child: InteractiveViewer(
                    key: ValueKey<String>('property-image-zoom-${image.id}'),
                    transformationController: _imageControllers[index],
                    minScale: 1,
                    maxScale: 4,
                    child: SizedBox.expand(
                      child: AppNetworkImage(
                        imageUrl: image.url!,
                        fit: BoxFit.contain,
                        semanticLabel:
                            'Property photo ${index + 1} of $imageCount',
                        fallback: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (imageCount > 1) ...[
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
                onPressed: _page == imageCount - 1
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
    _resetZoom(_page);
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

  void _toggleZoom(int index, Offset focalPoint) {
    final controller = _imageControllers[index];
    if (controller.value.getMaxScaleOnAxis() > 1) {
      controller.value = Matrix4.identity();
      return;
    }

    const scale = 2.5;
    controller.value = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1);
  }

  void _resetZoom(int index) {
    _imageControllers[index].value = Matrix4.identity();
  }

  void _zoomChanged(int index) {
    if (index != _page) return;
    final isZoomed = _imageControllers[index].value.getMaxScaleOnAxis() > 1;
    if (isZoomed == _isZoomed) return;
    setState(() => _isZoomed = isZoomed);
  }
}
