import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_filter.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:flutter/material.dart';

/// Opens the approved server-side feed filter controls.
Future<FeedFilter?> showFeedFilterSheet(
  BuildContext context, {
  required FeedFilter filter,
}) {
  return AppSheet.show<FeedFilter>(
    context,
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
          TextField(
            controller: _locationController,
            // The API accepts a trimmed location of 1 through 120 characters.
            maxLength: 120,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Search locations',
              counterText: '',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context, const FeedFilter()),
                child: const Text('Clear'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _apply,
                child: const Text('Apply'),
              ),
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
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
