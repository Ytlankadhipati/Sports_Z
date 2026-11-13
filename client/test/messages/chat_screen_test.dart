import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sports_z/features/m4_common/counterpart.dart';
import 'package:sports_z/features/messages/data/models/conversation_item.dart';
import 'package:sports_z/features/messages/data/models/message_item.dart';
import 'package:sports_z/features/messages/data/repositories/messages_repository.dart';
import 'package:sports_z/features/messages/presentation/controllers/messages_controller.dart';
import 'package:sports_z/features/messages/presentation/screens/chat_screen.dart';

/// M03 chat states: loading, error, empty, sending, failed (retry), read-only.
class _FakeMessagesRepository extends MessagesRepository {
  _FakeMessagesRepository({required this.pageHandler, this.sendHandler})
      : super(Dio());

  Future<MessagePage> Function() pageHandler;
  Future<MessageItem> Function(String text)? sendHandler;
  int loadCalls = 0;
  final List<String> sentTexts = [];

  @override
  Future<MessagePage> messages(String conversationId, {String? cursor}) {
    loadCalls++;
    return pageHandler();
  }

  @override
  Future<MessageItem> send(String conversationId, String text) {
    sentTexts.add(text);
    return sendHandler!(text);
  }

  @override
  Future<void> markRead(String conversationId) async {}
}

MessagePage _page({
  List<MessageItem> messages = const [],
  bool readOnly = false,
  String? reason,
}) => MessagePage(
  conversation: ConversationItem(
    id: 'c1',
    counterpart: const Counterpart(userId: 'u2', name: 'Coach V'),
    unreadCount: 0,
    muted: false,
    readOnly: readOnly,
    readOnlyReason: reason,
  ),
  messages: messages,
);

MessageItem _message(String id, String text, {bool mine = false}) =>
    MessageItem(id: id, text: text, senderIsMe: mine);

Widget _app(_FakeMessagesRepository repository) => ProviderScope(
  overrides: [messagesRepositoryProvider.overrideWithValue(repository)],
  child: const MaterialApp(home: ChatScreen(conversationId: 'c1')),
);

void main() {
  testWidgets('M03 shows a spinner while the conversation loads', (
      tester,
      ) async {
    final pending = Completer<MessagePage>();
    await tester.pumpWidget(
      _app(_FakeMessagesRepository(pageHandler: () => pending.future)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(_page());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('M03 shows the empty state and the composer', (tester) async {
    await tester.pumpWidget(
      _app(_FakeMessagesRepository(pageHandler: () async => _page())),
    );
    await tester.pumpAndSettle();

    expect(find.text('No messages yet.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('M03 shows messages from both sides, newest at the bottom', (
      tester,
      ) async {
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(
        messages: [
          _message('m2', 'Welcome to the team', mine: false),
          _message('m1', 'Hello coach', mine: true),
        ],
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Hello coach'), findsOneWidget);
    expect(find.text('Welcome to the team'), findsOneWidget);
    expect(find.text('Coach V'), findsOneWidget);
  });

  testWidgets('M03 load error shows Retry and recovers', (tester) async {
    var attempts = 0;
    final repository = _FakeMessagesRepository(
      pageHandler: () async {
        attempts++;
        if (attempts == 1) throw Exception('Network down');
        return _page(messages: [_message('m1', 'Hi there')]);
      },
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Hi there'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Hi there'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(repository.loadCalls, 2);
  });

  testWidgets('M03 shows Sending… until the server confirms', (tester) async {
    final pendingSend = Completer<MessageItem>();
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(),
      sendHandler: (_) => pendingSend.future,
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'See you at 6');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('See you at 6'), findsOneWidget);
    expect(find.text('Sending…'), findsOneWidget);
    // The input is cleared as soon as the message is queued.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );

    pendingSend.complete(_message('m9', 'See you at 6', mine: true));
    await tester.pumpAndSettle();

    expect(find.text('See you at 6'), findsOneWidget);
    expect(find.text('Sending…'), findsNothing);
    expect(repository.sentTexts, ['See you at 6']);
  });

  testWidgets('M03 failed message can be retried by tapping it', (
      tester,
      ) async {
    var shouldFail = true;
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(),
      sendHandler: (text) async {
        if (shouldFail) throw Exception('Network down');
        return _message('m9', text, mine: true);
      },
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Are you free?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Failed. Tap to retry'), findsOneWidget);
    expect(find.text('Are you free?'), findsOneWidget);

    // The error snackbar must not cover the bubble we are about to tap.
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    shouldFail = false;
    await tester.tap(find.text('Are you free?'));
    await tester.pumpAndSettle();

    expect(find.text('Failed. Tap to retry'), findsNothing);
    expect(find.text('Are you free?'), findsOneWidget);
    expect(repository.sentTexts, ['Are you free?', 'Are you free?']);
  });

  testWidgets('M03 does not send an empty message', (tester) async {
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(),
      sendHandler: (text) async => _message('m9', text, mine: true),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(repository.sentTexts, isEmpty);
  });

  testWidgets('M03 read-only conversation hides the composer and says why', (
      tester,
      ) async {
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(
        messages: [_message('m1', 'Earlier message')],
        readOnly: true,
        reason: 'basis_ended',
      ),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(find.text('Earlier message'), findsOneWidget);
    expect(
      find.text(
        'You are no longer connected, so you can only read this conversation.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send), findsNothing);
  });

  testWidgets('M03 blocked conversation shows the neutral message', (
      tester,
      ) async {
    final repository = _FakeMessagesRepository(
      pageHandler: () async => _page(readOnly: true, reason: 'blocked'),
    );
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();

    expect(
      find.text('This conversation is no longer available.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
  });
}