import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Opens the approved server-side feed filter controls.
Future<FeedFilter?> showFeedFilterSheet(
  BuildContext context, {
  required FeedFilter filter,
}) {
  // The native default covers 92% of the screen. The bottom 40% keeps this
  // small form restrained; longer states and keyboard use remain scrollable.
  const cupertinoTopGap = 0.6;

  return AppSheet.show<FeedFilter>(
    context,
    cupertinoTopGap: cupertinoTopGap,
    child: _FeedFilterSheet(filter: filter),
  );
}

final class _FeedFilterSheet extends StatefulWidget {
  const _FeedFilterSheet({required this.filter});

  final FeedFilter filter;

  @override
  State<_FeedFilterSheet> createState() => _FeedFilterSheetState();
}

final class _FeedFilterSheetState extends State<_FeedFilterSheet> {
  late PostType? _postType = widget.filter.postType;
  late RequestType? _requestType = widget.filter.requestType;
  late PropertyStatus? _propertyStatus = widget.filter.propertyStatus;
  late final TextEditingController _locationController = TextEditingController(
    text: widget.filter.location,
  );

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // The single-child scroll view keeps every control reachable when the
    // keyboard compresses the sheet on small screens.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.large,
        AppSpacing.xlarge,
        AppSpacing.xlarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: AppTypography.brand(colors)),
          const SizedBox(height: AppSpacing.large),
          Text('Post type', style: AppTypography.bodyStrong(colors)),
          const SizedBox(height: AppSpacing.small),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              _FilterChoice(
                label: 'All',
                selected: _postType == null,
                onSelected: () {
                  setState(() {
                    _postType = null;
                    _requestType = null;
                    _propertyStatus = null;
                  });
                },
              ),
              _FilterChoice(
                label: 'General',
                selected: _postType == PostType.general,
                onSelected: () {
                  setState(() {
                    _postType = PostType.general;
                    _requestType = null;
                    _propertyStatus = null;
                  });
                },
              ),
              _FilterChoice(
                label: 'Request',
                selected: _postType == PostType.request,
                onSelected: () {
                  setState(() {
                    _postType = PostType.request;
                    _propertyStatus = null;
                  });
                },
              ),
              _FilterChoice(
                label: 'Property',
                selected: _postType == PostType.property,
                onSelected: () {
                  setState(() {
                    _postType = PostType.property;
                    _requestType = null;
                  });
                },
              ),
            ],
          ),
          if (_postType == PostType.request) ...[
            const SizedBox(height: AppSpacing.large),
            Text('Request type', style: AppTypography.bodyStrong(colors)),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                _FilterChoice(
                  label: 'Any',
                  selected: _requestType == null,
                  onSelected: () {
                    setState(() => _requestType = null);
                  },
                ),
                _FilterChoice(
                  label: 'Looking to buy',
                  selected: _requestType == RequestType.lookingToBuy,
                  onSelected: () {
                    setState(() => _requestType = RequestType.lookingToBuy);
                  },
                ),
                _FilterChoice(
                  label: 'Looking to rent',
                  selected: _requestType == RequestType.lookingToRent,
                  onSelected: () {
                    setState(() => _requestType = RequestType.lookingToRent);
                  },
                ),
              ],
            ),
          ],
          if (_postType == PostType.property) ...[
            const SizedBox(height: AppSpacing.large),
            Text('Property status', style: AppTypography.bodyStrong(colors)),
            const SizedBox(height: AppSpacing.small),
            Wrap(
              spacing: AppSpacing.small,
              children: [
                _FilterChoice(
                  label: 'Any',
                  selected: _propertyStatus == null,
                  onSelected: () {
                    setState(() => _propertyStatus = null);
                  },
                ),
                _FilterChoice(
                  label: 'For sale',
                  selected: _propertyStatus == PropertyStatus.forSale,
                  onSelected: () {
                    setState(() => _propertyStatus = PropertyStatus.forSale);
                  },
                ),
                _FilterChoice(
                  label: 'For rent',
                  selected: _propertyStatus == PropertyStatus.forRent,
                  onSelected: () {
                    setState(() => _propertyStatus = PropertyStatus.forRent);
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          Text('Location', style: AppTypography.bodyStrong(colors)),
          const SizedBox(height: AppSpacing.small),
          _FilterField(controller: _locationController),
          const SizedBox(height: AppSpacing.large),
          Row(
            children: [
              _ClearAction(
                onPressed: () => Navigator.pop(context, const FeedFilter()),
              ),
              const Spacer(),
              _ApplyAction(onPressed: _apply),
            ],
          ),
        ],
      ),
    );
  }

  void _apply() {
    Navigator.pop(
      context,
      FeedFilter(
        postType: _postType,
        requestType: _postType == PostType.request ? _requestType : null,
        propertyStatus: _postType == PostType.property ? _propertyStatus : null,
        location: _locationController.text.trim(),
      ),
    );
  }
}

/// One selectable filter value in the active platform's control family.
///
/// The approved chip-group structure is kept on both platforms; only the
/// control family changes. Four long labels never become a cramped segmented
/// control.
final class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppIconSize.textButtonTapTarget),
        pressedOpacity: 0.6,
        onPressed: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.small,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.brandTint : null,
            border: selected
                ? null
                : Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
            borderRadius: AppRadii.pill,
          ),
          child: Text(
            label,
            style: AppTypography.caption(
              colors,
              color: selected ? colors.brandText : colors.textPrimary,
            ),
          ),
        ),
      );
    }
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

/// The location input in the active platform's control family.
final class _FilterField extends StatelessWidget {
  const _FilterField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // The API accepts a trimmed location of 1 through 120 characters.
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoTextField(
        controller: controller,
        maxLength: 120,
        textInputAction: TextInputAction.done,
        placeholder: 'Search locations',
        style: AppTypography.body(colors),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.small,
        ),
      );
    }
    return TextField(
      controller: controller,
      maxLength: 120,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'Search locations',
        counterText: '',
        border: OutlineInputBorder(),
      ),
    );
  }
}

/// The cancel action in the active platform's control family.
final class _ClearAction extends StatelessWidget {
  const _ClearAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(AppIconSize.textButtonTapTarget),
        onPressed: onPressed,
        child: Text(
          'Clear',
          style: AppTypography.bodyMedium(
            AppColors.of(context),
            color: AppColors.of(context).textTertiary,
          ),
        ),
      );
    }
    return TextButton(onPressed: onPressed, child: const Text('Clear'));
  }
}

/// The apply action in the active platform's control family.
final class _ApplyAction extends StatelessWidget {
  const _ApplyAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoButton(
        color: AppColors.of(context).brand,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.small,
        ),
        onPressed: onPressed,
        child: Text(
          'Apply',
          style: AppTypography.bodyMedium(AppColors.of(context)),
        ),
      );
    }
    return FilledButton(onPressed: onPressed, child: const Text('Apply'));
  }
}
