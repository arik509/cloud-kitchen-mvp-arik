import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter sends only the stored message ID to notification dispatch', () {
    final source = File(
      'lib/features/notifications/data/notification_dispatcher.dart',
    ).readAsStringSync().toLowerCase();
    expect(source, contains("body: {'message_id': messageid}"));
    expect(source, isNot(contains('recipient_id')));
    expect(source, isNot(contains('customer_id')));
    expect(source, isNot(contains('owner_id')));
  });

  test(
    'Edge Function authenticates sender and keeps FCM credentials server-side',
    () {
      final source = File(
        'supabase/functions/send-chat-notification/index.ts',
      ).readAsStringSync();
      expect(source, contains('authenticatedUserId'));
      expect(source, contains('event.sender_id !== callerId'));
      expect(source, contains('event.recipient_id === callerId'));
      expect(source, contains('FIREBASE_SERVICE_ACCOUNT_JSON'));
      expect(source, contains('https://fcm.googleapis.com/v1/projects/'));
      expect(source, isNot(contains('recipient_id?:')));
    },
  );

  test(
    'no server credential pattern is present in tracked Flutter sources',
    () {
      final dart = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(dart, isNot(contains('FIREBASE_SERVICE_ACCOUNT_JSON')));
      expect(dart.toLowerCase(), isNot(contains('service_role')));
      expect(dart, isNot(matches(RegExp(r'-----BEGIN PRIVATE KEY-----'))));
    },
  );
}
