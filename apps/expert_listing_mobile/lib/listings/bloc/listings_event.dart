import 'package:equatable/equatable.dart';

/// User and lifecycle actions for the property catalog.
sealed class ListingsEvent extends Equatable {
  const ListingsEvent();

  @override
  List<Object?> get props => const [];
}

/// Loads the first property page.
final class ListingsStarted extends ListingsEvent {
  /// Creates the initial-load event.
  const ListingsStarted();
}

/// Refreshes the property catalog while retaining visible cards.
final class ListingsRefreshed extends ListingsEvent {
  /// Creates the refresh event.
  const ListingsRefreshed();
}

/// Loads the next cursor page when one exists.
final class ListingsNextPageRequested extends ListingsEvent {
  /// Creates the next-page event.
  const ListingsNextPageRequested();
}

/// Retries the failed first page or refresh.
final class ListingsRetryRequested extends ListingsEvent {
  /// Creates the retry event.
  const ListingsRetryRequested();
}
