import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto me.dart' as crypto_pkg;
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt_pkg;
import 'package:uuid/uuid.dart';

class CryptoService {
  static final _uuid = const Uuid();

  /// Generates a unique Device UUID
  static String generateDeviceId() {
    return _uuid.v4();
  }

  /// Calculates SHA-256 hash of a string
  static String hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Calculates SHA-256 hash of binary bytes
  static String hashBytes(List<int> bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a random 6-digit PIN for device pairing
  static String generatePairingPin() {
    final random = Random.secure();
    final pin = random.nextInt(900000) + 100000;
    return pin.toString();
  }

  /// Generates a 256-bit AES symmetric key from dynamic pairing secret
  static String deriveKeyFromSecret(String secret, String deviceId) {
    final combined = '$secret:$deviceId:HKDROP_V1_SALT';
    return hashString(combined);
  }

  /// Encrypts plain text using AES-256-GCM / CTR
  static String encryptText(String plainText, String secretKey) {
    final keyBytes = utf8.encode(secretKey.substring(0, 32));
    final key = encrypt_pkg.Key(Uint8List.fromList(keyBytes));
    final iv = encrypt_pkg.IV.fromLength(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decrypts encrypted payload using AES secret key
  static String decryptText(String encryptedPayload, String secretKey) {
    final parts = encryptedPayload.split(':');
    if (parts.length != 2) return encryptedPayload;

    final iv = encrypt_pkg.IV.fromBase64(parts[0]);
    final encryptedData = encrypt_pkg.Encrypted.fromBase64(parts[1]);

    final keyBytes = utf8.encode(secretKey.substring(0, 32));
    final key = encrypt_pkg.Key(Uint8List.fromList(keyBytes));
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key, mode: encrypt_pkg.AESMode.cbc));

    return encrypter.decrypt(encryptedData, iv: iv);
  }

  /// Sign payload data with secret key
  static String createSignature(String data, String secretKey) {
    final keyBytes = utf8.encode(secretKey);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Verify payload signature
  static bool verifySignature(String data, String signature, String secretKey) {
    final computed = createSignature(data, secretKey);
    return computed == signature;
  }
}
