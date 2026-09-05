import 'package:app_ui/app_ui.dart';
import 'package:expert_listing/feed/view/create_post_prompt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the prompt outlines once after feed data becomes visible', (
    tester,
  ) async {
    var showInvitation = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return CreatePostPrompt(
                onNotice: (_) {},
                showInvitation: showInvitation,
              );
            },
          ),
        ),
      ),
    );

    Color outlineColor() {
      final box = tester.widget<DecoratedBox>(
        find.byKey(
          const ValueKey<String>('create-post-invitation-outline'),
        ),
      );
      final border = (box.decoration as BoxDecoration).border! as Border;
      return border.top.color;
    }

    final initialRect = tester.getRect(find.byType(AppPressable));
    expect(outlineColor().a, 0);

    setHostState(() => showInvitation = true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(outlineColor().a, greaterThan(0.5));
    expect(tester.getRect(find.byType(AppPressable)), initialRect);

    await tester.pump(const Duration(milliseconds: 600));
    expect(outlineColor().a, greaterThan(0.5));

    await tester.pumpAndSettle();
    expect(outlineColor().a, 0);

    setHostState(() => showInvitation = false);
    await tester.pump();
    setHostState(() => showInvitation = true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(outlineColor().a, 0, reason: 'later feed changes do not replay it');
  });

  testWidgets('reduced motion skips the invitation outline', (tester) async {
    var showInvitation = false;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return CreatePostPrompt(
                  onNotice: (_) {},
                  showInvitation: showInvitation,
                );
              },
            ),
          ),
        ),
      ),
    );

    setHostState(() => showInvitation = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('create-post-invitation-outline')),
    );
    final border = (box.decoration as BoxDecoration).border! as Border;
    expect(border.top.color.a, 0);
  });
}
