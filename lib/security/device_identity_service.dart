import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import 'crypto_service.dart';

class DeviceIdentityService {
  static final DeviceIdentityService _instance = DeviceIdentityService._internal();
  factory DeviceIdentityService() => _instance;
  DeviceIdentityService._internal();

  final _storage = const FlutterSecureStorage();

  String? _deviceId;
  String? _deviceName;
  String? _platform;
  String? _publicKey;
  String? _privateKey;

  String get deviceId => _deviceId ?? 'unknown_device';
  String get deviceName => _deviceName ?? 'HK Drop Device';
  String get platform => _platform ?? 'unknown';
  String get publicKey => _publicKey ?? '';

  Future<void> init() async {
    // 1. Get platform
    if (Platform.isAndroid) _platform = 'android';
    else if (Platform.isIOS) _platform = 'ios';
    else if (Platform.isWindows) _platform = 'windows';
    else if (Platform.isMacOS) _platform = 'macos';
    else if (Platform.isLinux) _platform = 'linux';
    else _platform = 'unknown';

    // 2. Load or generate Device ID
    _deviceId = await _storage.read(key: AppConstants.keyDeviceId);
    if (_deviceId == null) {
      _deviceId = CryptoService.generateDeviceId();
      await _storage.write(key: AppConstants.keyDeviceId, value: _deviceId);
    }

    // 3. Load or set Device Name
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isWindows) {
        final winInfo = await deviceInfo.windowsInfo;
        _deviceName = winInfo.computerName;
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _deviceName = macInfo.computerName;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _deviceName = linuxInfo.name;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceName = iosInfo.name;
      }
    } catch (_) {
      _deviceName = 'HK Drop Device';
    }

    // 4. Generate device keypair if needed
    _publicKey = await _storage.read(key: AppConstants.keyPublicKey);
    _privateKey = await _storage.read(key: AppConstants.keyPrivateKey);

    if (_publicKey == null || _privateKey == null) {
      _publicKey = CryptoService.hashString('PUB:$_deviceId:$_deviceName');
      _privateKey = CryptoService.hashString('PRIV:$_deviceId:$_deviceName');
      await _storage.write(key: AppConstants.keyPublicKey, value: _publicKey);
      await _storage.write(key: AppConstants.keyPrivateKey, value: _privateKey);
    }
  }
}
