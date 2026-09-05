import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/feed_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('header buttons expose labels and genuine 48px targets', (
    tester,
  ) async {
    var taps = 0;
    final notices = <String>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: FeedHeader(
              onLogoPressed: () => taps++,
              onNotice: notices.add,
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(FeedHeader)).height, 72);

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

      final messages = find.bySemanticsLabel('Messages');
      expect(
        tester.getSemantics(messages).flagsCollection.isButton,
        isTrue,
      );
      final messagesButton = find.ancestor(
        of: messages,
        matching: find.byType(AppPressable),
      );
      final messagesRect = tester.getRect(messagesButton);
      expect(messagesRect.size, const Size.square(AppIconSize.tapTarget));
      await tester.tapAt(messagesRect.bottomRight + const Offset(-1, -1));
      await tester.pump();
      expect(notices, ['Messages are not part of this preview.']);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
