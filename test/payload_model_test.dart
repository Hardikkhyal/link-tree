import 'package:flutter_test/flutter_test.dart';
import '../lib/network/models/device_model.dart';
import '../lib/network/models/payload_model.dart';

void main() {
  group('Payload and Model JSON Serialization Tests', () {
    test('DeviceModel Serialization', () {
      final device = DeviceModel(
        id: 'dev-123',
        name: 'Pixel 7',
        platform: 'android',
        ipAddress: '192.168.1.50',
        port: 45789,
        publicKey: 'pubkey123',
        isPaired: true,
      );

      final json = device.toJson();
      expect(json['id'], equals('dev-123'));
      expect(json['isPaired'], isTrue);

      final decoded = DeviceModel.fromJson(json);
      expect(decoded.name, equals('Pixel 7'));
      expect(decoded.deviceType, equals(DeviceType.mobile));
    });

    test('TextPayload Serialization', () {
      final textPayload = TextPayload(
        text: 'OTP: 492019',
        category: TextCategory.otp,
        senderId: 'dev-laptop',
        senderName: 'DELL XPS 15',
      );

      final json = textPayload.toJson();
      expect(json['category'], equals('otp'));

      final decoded = TextPayload.fromJson(json);
      expect(decoded.category, equals(TextCategory.otp));
      expect(decoded.text, equals('OTP: 492019'));
    });

    test('FileMetadata Serialization', () {
      final meta = FileMetadata(
        transferId: 'tx-001',
        filename: 'presentation.pdf',
        filesize: 10485760,
        mimeType: 'application/pdf',
        sha256: 'abcdef1234567890',
        senderId: 'dev-phone',
        senderName: 'iPhone 14',
        totalChunks: 20,
      );

      final json = meta.toJson();
      expect(json['filesize'], equals(10485760));

      final decoded = FileMetadata.fromJson(json);
      expect(decoded.filename, equals('presentation.pdf'));
      expect(decoded.totalChunks, equals(20));
    });
  });
}
