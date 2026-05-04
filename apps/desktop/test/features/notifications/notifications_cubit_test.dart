import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/entities/app_notification.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_desktop/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:fluxora_desktop/features/notifications/presentation/cubit/notifications_state.dart';

class _MockRepo extends Mock implements NotificationsRepository {}

AppNotification _n(
  String id, {
  String? readAt,
  NotificationCategory category = NotificationCategory.system,
}) {
  return AppNotification(
    id: id,
    type: NotificationType.info,
    category: category,
    title: 'title $id',
    message: 'msg $id',
    createdAt: '2026-05-04T10:00:00Z',
    readAt: readAt,
  );
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    // Default: live stream emits nothing.
    when(() => repo.liveStream()).thenAnswer((_) => const Stream.empty());
  });

  NotificationsCubit buildCubit() => NotificationsCubit(repository: repo);

  group('NotificationsCubit.start', () {
    test('initial state is NotificationsInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<NotificationsInitial>());
      cubit.close();
    });

    blocTest<NotificationsCubit, NotificationsState>(
      'emits [Loading, Loaded(unreadCount=1)] when list resolves with 1 unread',
      build: () {
        when(() => repo.list()).thenAnswer(
          (_) async => [_n('a'), _n('b', readAt: '2026-05-04T11:00:00Z')],
        );
        return buildCubit();
      },
      act: (c) => c.start(),
      expect: () => [
        isA<NotificationsLoading>(),
        isA<NotificationsLoaded>()
            .having((s) => s.items.length, 'items', 2)
            .having((s) => s.unreadCount, 'unread', 1),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'emits Failure(message) when list throws ApiException',
      build: () {
        when(() => repo.list()).thenThrow(
          const ApiException(message: 'forbidden', statusCode: 403),
        );
        return buildCubit();
      },
      act: (c) => c.start(),
      expect: () => [
        isA<NotificationsLoading>(),
        isA<NotificationsFailure>().having((s) => s.message, 'message', 'forbidden'),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'emits Failure with default message on generic exception',
      build: () {
        when(() => repo.list()).thenThrow(Exception('boom'));
        return buildCubit();
      },
      act: (c) => c.start(),
      expect: () => [
        isA<NotificationsLoading>(),
        isA<NotificationsFailure>().having(
          (s) => s.message,
          'message',
          'Unable to reach server.',
        ),
      ],
    );
  });

  group('NotificationsCubit.markRead', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'sets readAt and decrements unreadCount on success',
      build: () {
        when(() => repo.markRead('a')).thenAnswer((_) async {});
        return buildCubit();
      },
      seed: () => NotificationsLoaded(items: [_n('a'), _n('b')], unreadCount: 2),
      act: (c) => c.markRead('a'),
      expect: () => [
        isA<NotificationsLoaded>()
            .having((s) => s.unreadCount, 'unread', 1)
            .having(
              (s) => s.items.firstWhere((n) => n.id == 'a').readAt,
              'a.readAt',
              isNotNull,
            ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'is a no-op when target is already read (no API call, no emit)',
      build: () => buildCubit(),
      seed: () => NotificationsLoaded(
        items: [_n('a', readAt: '2026-05-04T11:00:00Z')],
        unreadCount: 0,
      ),
      act: (c) => c.markRead('a'),
      expect: () => <NotificationsState>[],
      verify: (_) {
        verifyNever(() => repo.markRead(any()));
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'rethrows on ApiException',
      build: () {
        when(() => repo.markRead('a')).thenThrow(
          const ApiException(message: 'nope', statusCode: 500),
        );
        return buildCubit();
      },
      seed: () => NotificationsLoaded(items: [_n('a')], unreadCount: 1),
      act: (c) async {
        await expectLater(() => c.markRead('a'), throwsA(isA<ApiException>()));
      },
      expect: () => <NotificationsState>[],
    );
  });

  group('NotificationsCubit.markAllRead', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'marks every unread item read and zeroes unreadCount',
      build: () {
        when(() => repo.markAllRead()).thenAnswer((_) async {});
        return buildCubit();
      },
      seed: () => NotificationsLoaded(
        items: [_n('a'), _n('b'), _n('c', readAt: '2026-05-04T11:00:00Z')],
        unreadCount: 2,
      ),
      act: (c) => c.markAllRead(),
      expect: () => [
        isA<NotificationsLoaded>().having((s) => s.unreadCount, 'unread', 0),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'rethrows on failure',
      build: () {
        when(() => repo.markAllRead()).thenThrow(Exception('boom'));
        return buildCubit();
      },
      seed: () => NotificationsLoaded(items: [_n('a')], unreadCount: 1),
      act: (c) async {
        await expectLater(c.markAllRead(), throwsException);
      },
      expect: () => <NotificationsState>[],
    );
  });

  group('NotificationsCubit.dismiss', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'removes the item and recomputes unreadCount on success',
      build: () {
        when(() => repo.dismiss('a')).thenAnswer((_) async {});
        return buildCubit();
      },
      seed: () => NotificationsLoaded(items: [_n('a'), _n('b')], unreadCount: 2),
      act: (c) => c.dismiss('a'),
      expect: () => [
        isA<NotificationsLoaded>()
            .having((s) => s.items.length, 'remaining', 1)
            .having((s) => s.items.first.id, 'remaining id', 'b')
            .having((s) => s.unreadCount, 'unread', 1),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'rethrows on failure and leaves state untouched',
      build: () {
        when(() => repo.dismiss('a')).thenThrow(
          const ApiException(message: 'gone', statusCode: 404),
        );
        return buildCubit();
      },
      seed: () => NotificationsLoaded(items: [_n('a')], unreadCount: 1),
      act: (c) async {
        await expectLater(() => c.dismiss('a'), throwsA(isA<ApiException>()));
      },
      expect: () => <NotificationsState>[],
    );
  });

  group('NotificationsCubit live stream', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'prepends a new live notification and bumps unreadCount',
      build: () {
        final controller = StreamController<AppNotification>();
        when(() => repo.list()).thenAnswer((_) async => [_n('a')]);
        when(() => repo.liveStream()).thenAnswer((_) => controller.stream);
        addTearDown(controller.close);
        // Surface the controller through the mock so act: can push.
        when(() => repo.dismiss('__live_test__')).thenAnswer((_) async {
          controller.add(_n('b'));
        });
        return buildCubit();
      },
      act: (c) async {
        await c.start();
        await c.dismiss('__live_test__');
        // Give the listen callback a microtask to apply.
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [
        isA<NotificationsLoading>(),
        isA<NotificationsLoaded>().having((s) => s.items.length, 'initial', 1),
        isA<NotificationsLoaded>()
            .having((s) => s.items.length, 'after live emit', 2)
            .having((s) => s.items.first.id, 'newest first', 'b')
            .having((s) => s.unreadCount, 'unread', 2),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'duplicate id from live stream is ignored',
      build: () {
        final controller = StreamController<AppNotification>();
        when(() => repo.list()).thenAnswer((_) async => [_n('a')]);
        when(() => repo.liveStream()).thenAnswer((_) => controller.stream);
        addTearDown(controller.close);
        when(() => repo.dismiss('__live_dup__')).thenAnswer((_) async {
          controller.add(_n('a'));
        });
        return buildCubit();
      },
      act: (c) async {
        await c.start();
        await c.dismiss('__live_dup__');
        await Future<void>.delayed(Duration.zero);
      },
      // Initial Loading→Loaded pair only; the duplicate doesn't re-emit.
      expect: () => [
        isA<NotificationsLoading>(),
        isA<NotificationsLoaded>().having((s) => s.items.length, 'unchanged', 1),
      ],
    );
  });
}
