import 'dart:convert';
import '../network/discovery_service.dart';
import '../network/models/device_model.dart';
import 'crypto_service.dart';
import 'device_identity_service.dart';
import 'trust_store.dart';

class PairingPayload {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final int port;
  final String publicKey;
  final String secretToken;

  PairingPayload({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.publicKey,
    required this.secretToken,
  });

  String toRawString() {
    final map = {
      'id': deviceId,
      'name': deviceName,
      'platform': platform,
      'ip': ipAddress,
      'port': port,
      'pubKey': publicKey,
      'token': secretToken,
    };
    return jsonEncode(map);
  }

  factory PairingPayload.fromRawString(String raw) {
    final Map<String, dynamic> json = jsonDecode(raw);
    return PairingPayload(
      deviceId: json['id'] as String,
      deviceName: json['name'] as String,
      platform: json['platform'] as String,
      ipAddress: json['ip'] as String,
      port: json['port'] as int? ?? 45789,
      publicKey: json['pubKey'] as String,
      secretToken: json['token'] as String,
    );
  }
}

class PairingService {
  static final PairingService _instance = PairingService._internal();
  factory PairingService() => _instance;
  PairingService._internal();

  /// Generates QR Code data payload for this device
  Future<PairingPayload> generateMyPairingPayload() async {
    final identity = DeviceIdentityService();
    final localIp = await DiscoveryService().getLocalIpAddress() ?? '127.0.0.1';
    final token = CryptoService.generatePairingPin();

    return PairingPayload(
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
      platform: identity.platform,
      ipAddress: localIp,
      port: 45789,
      publicKey: identity.publicKey,
      secretToken: token,
    );
  }

  /// Handles pairing execution after scanning target device QR code
  Future<bool> processPairingQR(String qrData) async {
    try {
      final payload = PairingPayload.fromRawString(qrData);

      final device = DeviceModel(
        id: payload.deviceId,
        name: payload.deviceName,
        platform: payload.platform,
        ipAddress: payload.ipAddress,
        port: payload.port,
        publicKey: payload.publicKey,
        isPaired: true,
      );

      // Save to TrustStore
      await TrustStore().addOrUpdatePairedDevice(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Process PIN pairing exchange
  Future<bool> processPairingPin(DeviceModel targetDevice, String pin) async {
    final device = targetDevice.copyWith(isPaired: true);
    await TrustStore().addOrUpdatePairedDevice(device);
    return true;
  }
}
