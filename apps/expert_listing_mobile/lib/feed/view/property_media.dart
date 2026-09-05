import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Figma's property media box is 388 by 260 at the reference width.
        final height = constraints.maxWidth * 260 / 388;
        return Column(
          children: [
            SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: AppRadii.image,
                child: PageView.builder(
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
                        image.url!,
                        index: index,
                        imageCount: images.length,
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
              ),
            ),
            if (images.length > 1) ...[
              const SizedBox(height: AppSpacing.xsmall),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => Container(
                    key: ValueKey<String>(
                      'property-media-${images.first.id}-indicator-$index',
                    ),
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? AppColors.of(context).brandDeep
                          : AppColors.of(context).border,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showImage(
    BuildContext context,
    String url, {
    required int index,
    required int imageCount,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(
          imageUrl: url,
          semanticLabel: 'Property photo ${index + 1} of $imageCount',
        ),
      ),
    );
  }
}

final class _FullScreenImageViewer extends StatelessWidget {
  const _FullScreenImageViewer({
    required this.imageUrl,
    required this.semanticLabel,
  });

  final String imageUrl;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
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
        body: LayoutBuilder(
          builder: (context, constraints) => InteractiveViewer(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: AppNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                semanticLabel: semanticLabel,
                fallback: const Center(
                  child: Icon(Icons.image_not_supported, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
