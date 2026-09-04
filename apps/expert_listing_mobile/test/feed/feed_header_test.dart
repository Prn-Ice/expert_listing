import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/feed_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wordmark keeps a 48px semantic tap region', (tester) async {
    var taps = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FeedHeader(
              onLogoPressed: () => taps++,
              onNotice: (_) {},
            ),
          ),
        ),
      );

      final wordmark = find.byKey(const ValueKey<String>('feed-wordmark'));
      expect(tester.getSize(wordmark), const Size(169, 48));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Expert Listing feed'))
            .flagsCollection
            .isButton,
        isTrue,
      );

      await tester.tap(wordmark);
      expect(taps, 1);
    } finally {
      semantics.dispose();
    }
  });
}
