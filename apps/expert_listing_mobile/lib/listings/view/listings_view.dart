import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/models/feed_load_result.dart';
import 'package:expert_listing/listings/bloc/listings_event.dart';
import 'package:expert_listing/listings/bloc/listings_state.dart';
import 'package:expert_listing/listings/listings_providers.dart';
import 'package:expert_listing/listings/view/listing_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The independently paginated property catalog destination.
class ListingsView extends ConsumerStatefulWidget {
  /// Creates the property catalog.
  const ListingsView({
    required this.isActive,
    required this.onListingPressed,
    super.key,
  });

  /// Whether this dashboard destination is currently visible.
  final bool isActive;

  /// Handles the intentionally unavailable property-details boundary.
  final VoidCallback onListingPressed;

  @override
  ConsumerState<ListingsView> createState() => _ListingsViewState();
}

final class _ListingsViewState extends ConsumerState<ListingsView> {
  final _scrollController = ScrollController();
  var _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreWhenNeeded);
    if (widget.isActive) _start();
  }

  @override
  void didUpdateWidget(covariant ListingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _start();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreWhenNeeded)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listingsBlocProvider);
    final usesCupertinoRefresh = context.isIos;
    final catalog = CustomScrollView(
      key: const PageStorageKey<String>('listings-scroll'),
      controller: _scrollController,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (usesCupertinoRefresh)
          CupertinoSliverRefreshControl(onRefresh: _refresh),
        const SliverToBoxAdapter(child: _ListingsHeader()),
        if (state.isShowingSavedListings)
          SliverToBoxAdapter(
            child: OfflineStatusBar(
              message: state.fallbackReason == FeedFallbackReason.connection
                  ? 'Offline · Showing saved properties'
                  : 'Showing saved properties',
              onRetry: _retry,
            ),
          ),
        if (state.refreshFailed)
          const SliverToBoxAdapter(
            child: _ListingsStatus(
              message:
                  "Couldn't refresh. Showing the properties already loaded.",
            ),
          ),
        _ListingsContent(
          state: state,
          onListingPressed: widget.onListingPressed,
          onRetry: _retry,
          onRetryNextPage: _retryNextPage,
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: usesCupertinoRefresh
          ? catalog
          : RefreshIndicator(onRefresh: _refresh, child: catalog),
    );
  }

  Future<void> _refresh() async {
    final bloc = ref.read(listingsBlocProvider.bloc);
    await (bloc..add(const ListingsRefreshed())).stream.firstWhere(
      (state) => !state.isRefreshing && !state.isInitialLoading,
    );
  }

  void _retry() =>
      ref.read(listingsBlocProvider.bloc).add(const ListingsRetryRequested());

  void _retryNextPage() => ref
      .read(listingsBlocProvider.bloc)
      .add(const ListingsNextPageRequested());

  void _loadMoreWhenNeeded() {
    if (_scrollController.position.extentAfter >= 360) return;
    final state = ref.read(listingsBlocProvider);
    if (state.nextPageFailed) return;
    _retryNextPage();
  }

  void _start() {
    if (_hasStarted) return;
    _hasStarted = true;
    ref.read(listingsBlocProvider.bloc).add(const ListingsStarted());
  }
}

final class _ListingsHeader extends StatelessWidget {
  const _ListingsHeader();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.xlarge,
        AppSpacing.large,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Properties', style: AppTypography.brand(colors)),
          const SizedBox(height: AppSpacing.xsmall),
          Text(
            'Homes worth a closer look.',
            style: AppTypography.body(colors, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

final class _ListingsContent extends StatelessWidget {
  const _ListingsContent({
    required this.state,
    required this.onListingPressed,
    required this.onRetry,
    required this.onRetryNextPage,
  });

  final ListingsState state;
  final VoidCallback onListingPressed;
  final VoidCallback onRetry;
  final VoidCallback onRetryNextPage;

  @override
  Widget build(BuildContext context) {
    if (state.isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    }
    if (state.failure case final failure? when state.listings.isEmpty) {
      final message = switch (failure.kind) {
        FeedFailureKind.connection =>
          "You're offline. Reconnect to load properties.",
        FeedFailureKind.service => 'Properties are unavailable. Try again.',
        FeedFailureKind.unavailable => "Couldn't load properties.",
      };
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _ListingsStatus(
          message: message,
          actionLabel: 'Try again',
          onPressed: onRetry,
        ),
      );
    }
    if (state.listings.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _ListingsStatus(message: 'No properties yet.'),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xlarge,
            0,
            AppSpacing.xlarge,
            AppSpacing.xxlarge,
          ),
          sliver: SliverList.separated(
            itemCount: state.listings.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.large),
            itemBuilder: (context, index) => ListingCard(
              listing: state.listings[index],
              onPressed: onListingPressed,
            ),
          ),
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
          ),
        if (state.nextPageFailed)
          SliverToBoxAdapter(
            child: Center(
              child: AppButton(
                onPressed: onRetryNextPage,
                minimumSize: const Size(64, 48),
                child: const Text('Try again'),
              ),
            ),
          ),
      ],
    );
  }
}

final class _ListingsStatus extends StatelessWidget {
  const _ListingsStatus({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
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
            Text(message, textAlign: TextAlign.center),
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
