import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/story_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stories expose exact outcomes without activating on drag', (
    tester,
  ) async {
    final notices = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: StoryStrip(onNotice: notices.add)),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Open Your Story'));
    await tester.pump();
    expect(notices, ['Story posting isn’t part of this preview.']);

    await tester.tap(find.bySemanticsLabel('Open Abba’s story'));
    await tester.pump();
    expect(notices.last, 'Story viewing isn’t part of this preview.');

    final strip = find.byType(ListView);
    await tester.drag(strip, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(notices, hasLength(2));
  });
}
