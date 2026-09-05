import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/post_types.dart';
import 'package:expert_listing/search/bloc/search_event.dart';
import 'package:expert_listing/search/bloc/search_state.dart';
import 'package:expert_listing/search/models/search_suggestion.dart';
import 'package:expert_listing/search/search_providers.dart';
import 'package:expert_listing/search/search_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The property and location autocomplete destination.
class SearchView extends ConsumerStatefulWidget {
  /// Creates the search destination.
  const SearchView({
    required this.isActive,
    required this.onPropertySelected,
    super.key,
  });

  /// Whether this destination currently owns focus.
  final bool isActive;

  /// Handles the intentionally unavailable property-details boundary.
  final ValueChanged<PropertySearchSuggestion> onPropertySelected;

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

final class _SearchViewState extends ConsumerState<SearchView> {
  static const _quickSearches = ['Lekki', 'Ikoyi', 'Ikeja GRA'];

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    ref.read(searchBlocProvider.bloc).add(const SearchStarted());
    if (widget.isActive) _requestFocus();
  }

  @override
  void didUpdateWidget(SearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _requestFocus();
    } else if (oldWidget.isActive && !widget.isActive) {
      _focusNode.unfocus();
    }
  }

  void _requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchBlocProvider);
    final colors = AppColors.of(context);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const PageStorageKey<String>('search-scroll'),
        primary: false,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xlarge,
              AppSpacing.xlarge,
              AppSpacing.xlarge,
              AppSpacing.medium,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Search', style: AppTypography.brand(colors)),
                  const SizedBox(height: AppSpacing.xsmall),
                  Text(
                    'Find a place by property or location.',
                    style: AppTypography.body(
                      colors,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.large),
                  _SearchField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (query) => ref
                        .read(searchBlocProvider.bloc)
                        .add(SearchQueryChanged(query)),
                  ),
                ],
              ),
            ),
          ),
          ..._content(state),
        ],
      ),
    );
  }

  ///FIXME - I dont like this. Just inline it, dont love widget functions
  List<Widget> _content(SearchState state) {
    if (state.query.isEmpty) {
      return [
        if (state.recentSearches.isNotEmpty)
          SliverToBoxAdapter(
            child: _RecentSearches(
              searches: state.recentSearches,
              onSelected: _applyQuery,
              onRemoved: (query) => ref
                  .read(searchBlocProvider.bloc)
                  .add(RecentSearchRemoved(query)),
              onCleared: () => ref
                  .read(searchBlocProvider.bloc)
                  .add(const RecentSearchesCleared()),
            ),
          ),
        SliverToBoxAdapter(
          child: _QuickSearches(
            searches: _quickSearches,
            onSelected: _applyQuery,
          ),
        ),
      ];
    }
    if (state.query.trim().length < 3) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(message: 'Type at least 3 characters.'),
        ),
      ];
    }
    if (state.isLoading) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Searching properties',
              child: const CircularProgressIndicator.adaptive(),
            ),
          ),
        ),
      ];
    }
    if (state.failure case final failure?) {
      final message = switch (failure) {
        SearchFailureKind.connection =>
          'Search needs a connection. Reconnect and try again.',
        SearchFailureKind.timeout =>
          'That search took too long. Try it once more.',
        SearchFailureKind.service =>
          'Property search is briefly unavailable. Try again.',
        SearchFailureKind.invalidResponse =>
          "Those results couldn't be displayed. Try again.",
      };
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(
            message: message,
            actionLabel: 'Try again',
            onPressed: () =>
                ref.read(searchBlocProvider.bloc).add(const SearchRetried()),
          ),
        ),
      ];
    }
    if (state.suggestions.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _SearchMessage(message: 'No matching properties yet.'),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xlarge,
          AppSpacing.small,
          AppSpacing.xlarge,
          AppSpacing.xxlarge,
        ),
        sliver: SliverList.separated(
          itemCount: state.suggestions.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.small),
          itemBuilder: (context, index) {
            final suggestion = state.suggestions[index];
            return switch (suggestion) {
              LocationSearchSuggestion() => _LocationSuggestionCard(
                suggestion: suggestion,
                onPressed: () => _applyQuery(suggestion.label),
              ),
              PropertySearchSuggestion() => _PropertySuggestionCard(
                suggestion: suggestion,
                onPressed: () {
                  ref
                      .read(searchBlocProvider.bloc)
                      .add(SearchSaved(state.query));
                  widget.onPropertySelected(suggestion);
                },
              ),
            };
          },
        ),
      ),
    ];
  }

  void _applyQuery(String query) {
    _controller.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(searchBlocProvider.bloc).add(SearchQueryChanged(query));
  }
}

final class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    if (context.isIos) {
      return CupertinoSearchTextField(
        key: const ValueKey<String>('property-search-field'),
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        placeholder: 'Search properties or locations',
        backgroundColor: colors.surface,
        borderRadius: AppRadii.pill,
        itemColor: colors.textSecondary,
        prefixIcon: AppIcon(
          AppIcons.search,
          color: colors.textSecondary,
        ),
        suffixIcon: const Icon(Icons.cancel),
        style: AppTypography.body(colors),
        placeholderStyle: AppTypography.body(
          colors,
          color: colors.textTertiary,
        ),
      );
    }

    return TextField(
      key: const ValueKey<String>('property-search-field'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.body(colors),
      decoration: InputDecoration(
        hintText: 'Search properties or locations',
        hintStyle: AppTypography.body(colors, color: colors.textTertiary),
        prefixIcon: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: AppIcon(
            AppIcons.search,
            color: colors.textSecondary,
          ),
        ),
        filled: true,
        fillColor: colors.surface,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.pill,
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

final class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.searches,
    required this.onSelected,
    required this.onRemoved,
    required this.onCleared,
  });

  final List<String> searches;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onRemoved;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.small,
        AppSpacing.xlarge,
        AppSpacing.large,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent', style: AppTypography.title(colors)),
              ),
              AppButton(onPressed: onCleared, child: const Text('Clear')),
            ],
          ),
          for (final search in searches)
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppIconSize.tapTarget,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppPressable(
                      onPressed: () => onSelected(search),
                      borderRadius: AppRadii.pill,
                      semanticLabel: 'Search again for $search',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(search, style: AppTypography.body(colors)),
                      ),
                    ),
                  ),
                  AppIconButton(
                    icon: AppIcons.postOverflow,
                    iconSize: AppIconSize.small,
                    tooltip: 'Remove $search',
                    onPressed: () => onRemoved(search),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final class _QuickSearches extends StatelessWidget {
  const _QuickSearches({required this.searches, required this.onSelected});

  final List<String> searches;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.medium,
        AppSpacing.xlarge,
        AppSpacing.xxlarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Explore Lagos', style: AppTypography.title(colors)),
          const SizedBox(height: AppSpacing.medium),
          Wrap(
            spacing: AppSpacing.small,
            runSpacing: AppSpacing.small,
            children: [
              for (final search in searches)
                AppPressable(
                  onPressed: () => onSelected(search),
                  borderRadius: AppRadii.pill,
                  color: colors.brandTint,
                  semanticLabel: 'Search $search',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.medium,
                    ),
                    child: Text(
                      search,
                      style: AppTypography.bodyMedium(
                        colors,
                        color: colors.brandText,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _LocationSuggestionCard extends StatelessWidget {
  const _LocationSuggestionCard({
    required this.suggestion,
    required this.onPressed,
  });

  final LocationSearchSuggestion suggestion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final count = suggestion.propertyCount;
    return AppPressable(
      onPressed: onPressed,
      color: colors.subtleSurface,
      borderRadius: AppRadii.card,
      semanticLabel: 'Search ${suggestion.label}, $count properties',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Row(
          children: [
            AppIcon(
              AppIcons.mapPin,
              color: colors.brandText,
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.label,
                    style: AppTypography.bodyStrong(colors),
                  ),
                  Text(
                    '$count ${count == 1 ? 'property' : 'properties'}',
                    style: AppTypography.meta(colors),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PropertySuggestionCard extends StatelessWidget {
  const _PropertySuggestionCard({
    required this.suggestion,
    required this.onPressed,
  });

  final PropertySearchSuggestion suggestion;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = suggestion.status == PropertyStatus.forSale
        ? 'For Sale'
        : 'For Rent';
    final imageUrl = suggestion.imageUrl;
    return AppPressable(
      key: ValueKey<String>('property-suggestion-${suggestion.propertyId}'),
      onPressed: onPressed,
      color: colors.surface,
      borderRadius: AppRadii.card,
      semanticLabel: '$status property in ${suggestion.location}',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadii.image,
              child: SizedBox.square(
                dimension: 76,
                child: ColoredBox(
                  color: colors.brandTint,
                  child: imageUrl == null
                      ? Center(
                          child: AppIcon(
                            AppIcons.mapPin,
                            color: colors.brandText,
                          ),
                        )
                      : AppNetworkImage(
                          imageUrl: imageUrl,
                          semanticLabel: 'Property in ${suggestion.location}',
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xsmall,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: AppTypography.caption(
                        colors,
                        color: colors.brandText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xsmall),
                    Text(
                      suggestion.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong(colors),
                    ),
                    const SizedBox(height: AppSpacing.xsmall),
                    Text(
                      suggestion.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.meta(colors),
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

final class _SearchMessage extends StatelessWidget {
  const _SearchMessage({this.message, this.actionLabel, this.onPressed});

  final String? message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxlarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message case final message?)
              Semantics(
                liveRegion: true,
                child: Text(message, textAlign: TextAlign.center),
              ),
            if (actionLabel case final label?) ...[
              const SizedBox(height: AppSpacing.medium),
              FilledButton(onPressed: onPressed, child: Text(label)),
            ],
          ],
        ),
      ),
    );
  }
}
