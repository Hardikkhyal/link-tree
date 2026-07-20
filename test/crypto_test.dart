import 'package:flutter_test/flutter_test.dart';
import '../lib/security/crypto_service.dart';

void main() {
  group('CryptoService Tests', () {
    test('SHA-256 Hash Computation', () {
      final input = 'HK_DROP_TEST_PAYLOAD';
      final hash = CryptoService.hashString(input);
      expect(hash.length, equals(64)); // SHA-256 hex string length
    });

    test('Pairing PIN Generation', () {
      final pin = CryptoService.generatePairingPin();
      expect(pin.length, equals(6));
      expect(int.tryParse(pin), isNotNull);
    });

    test('AES Encryption & Decryption Roundtrip', () {
      final plainText = 'https://github.com/hkdrop/privacy-first-sharing';
      final secretKey = CryptoService.hashString('SECRET_KEY_123456');

      final encrypted = CryptoService.encryptText(plainText, secretKey);
      expect(encrypted, isNot(equals(plainText)));

      final decrypted = CryptoService.decryptText(encrypted, secretKey);
      expect(decrypted, equals(plainText));
    });

    test('Signature Creation & Verification', () {
      final data = 'device-id-123:timestamp-1787163375';
      final secretKey = 'MY_SHARED_PAIRING_SECRET';

      final signature = CryptoService.createSignature(data, secretKey);
      expect(signature.isNotEmpty, isTrue);

      final isValid = CryptoService.verifySignature(data, signature, secretKey);
      expect(isValid, isTrue);

      final isInvalid = CryptoService.verifySignature(data, 'TAMPERED_SIG', secretKey);
      expect(isInvalid, isFalse);
    });
  });
}
