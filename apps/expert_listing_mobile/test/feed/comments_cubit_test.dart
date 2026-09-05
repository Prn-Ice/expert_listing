import 'dart:async';

import 'package:dio/dio.dart';
import 'package:expert_listing/feed/comments/comments_cubit.dart';
import 'package:expert_listing/feed/feed_repository.dart';
import 'package:expert_listing/feed/models/feed_comment.dart';
import 'package:expert_listing/feed/models/feed_post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'comments load oldest first and a successful submission appends',
    () async {
      final repository = _CommentsRepository(
        comments: [_comment(1, 'First'), _comment(2, 'Second')],
      );
      final cubit = CommentsCubit(postId: 42, repository: repository);
      addTearDown(cubit.close);

      await cubit.load();
      expect(cubit.state.comments.map((comment) => comment.body), [
        'First',
        'Second',
      ]);

      cubit.draftChanged('  Third  ');
      expect(await cubit.submit(), isTrue);
      expect(cubit.state.comments.last.body, 'Third');
      expect(cubit.state.draft, isEmpty);
      expect(repository.submittedBody, 'Third');
    },
  );

  test('a failed submission retains the exact draft for retry', () async {
    final repository = _CommentsRepository(failSubmission: true);
    final cubit = CommentsCubit(postId: 42, repository: repository);
    addTearDown(cubit.close);

    const draft = '  Is inspection still open?  ';
    cubit.draftChanged(draft);
    expect(await cubit.submit(), isFalse);

    expect(cubit.state.draft, draft);
    expect(cubit.state.failure, CommentsFailure.submit);
    expect(cubit.state.isSubmitting, isFalse);
  });

  test(
    'closing during a load does not emit through the closed cubit',
    () async {
      final repository = _PendingCommentsRepository();
      final cubit = CommentsCubit(postId: 42, repository: repository);

      final load = cubit.load();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repository.loadResult.complete(const []);

      await expectLater(load, completes);
    },
  );

  test(
    'a completed submission reconciles feed count after sheet disposal',
    () async {
      final repository = _PendingCommentsRepository();
      var added = 0;
      final cubit = CommentsCubit(
        postId: 42,
        repository: repository,
        onCommentAdded: () => added++,
      )..draftChanged('Still available?');

      final submit = cubit.submit();
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      repository.submitResult.complete(_comment(4, 'Still available?'));

      expect(await submit, isTrue);
      expect(added, 1);
    },
  );

  test('submission waits for the initial list to settle', () async {
    final repository = _PendingCommentsRepository();
    final cubit = CommentsCubit(postId: 42, repository: repository)
      ..draftChanged('Still available?');
    addTearDown(cubit.close);

    final load = cubit.load();
    await Future<void>.delayed(Duration.zero);
    expect(await cubit.submit(), isFalse);
    expect(repository.createCalls, 0);

    repository.loadResult.complete(const []);
    await load;
    expect(cubit.state.comments, isEmpty);
  });
}

final class _CommentsRepository extends FeedRepository {
  _CommentsRepository({this.comments = const [], this.failSubmission = false})
    : super(client: Dio());

  final List<FeedComment> comments;
  final bool failSubmission;
  String? submittedBody;

  @override
  Future<List<FeedComment>> loadComments(int postId) async => comments;

  @override
  Future<FeedComment> createComment({
    required int postId,
    required String body,
  }) async {
    submittedBody = body;
    if (failSubmission) throw const EngagementFailure();
    return _comment(3, body);
  }
}

final class _PendingCommentsRepository extends FeedRepository {
  _PendingCommentsRepository() : super(client: Dio());

  final loadResult = Completer<List<FeedComment>>();
  final submitResult = Completer<FeedComment>();
  int createCalls = 0;

  @override
  Future<List<FeedComment>> loadComments(int postId) => loadResult.future;

  @override
  Future<FeedComment> createComment({
    required int postId,
    required String body,
  }) {
    createCalls++;
    return submitResult.future;
  }
}

FeedComment _comment(int id, String body) => FeedComment(
  id: id,
  postId: 42,
  body: body,
  createdAt: DateTime.utc(2026, 9, 5, 12, id),
  author: const FeedAuthor(
    id: '11111111-1111-4111-8111-111111111111',
    handle: 'prince',
    displayName: 'Prince',
    role: 'Buyer',
    avatarUrl: null,
  ),
);
