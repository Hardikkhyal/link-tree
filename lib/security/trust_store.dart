import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/app_constants.dart';
import '../network/models/device_model.dart';

class TrustStore {
  static final TrustStore _instance = TrustStore._internal();
  factory TrustStore() => _instance;
  TrustStore._internal();

  final _storage = const FlutterSecureStorage();
  final Map<String, DeviceModel> _pairedDevices = {};

  bool _initialized = false;

  /// Initializes secure trust store from disk
  Future<void> init() async {
    if (_initialized) return;
    try {
      final rawData = await _storage.read(key: AppConstants.keyPairedDevices);
      if (rawData != null && rawData.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(rawData);
        for (var item in jsonList) {
          final device = DeviceModel.fromJson(Map<String, dynamic>.from(item));
          _pairedDevices[device.id] = device;
        }
      }
    } catch (e) {
      // In case of parsing error, start clean
      _pairedDevices.clear();
    }
    _initialized = true;
  }

  /// Returns list of all paired devices
  List<DeviceModel> get pairedDevices => _pairedDevices.values.toList();

  /// Check if a given device ID is paired and trusted
  bool isDeviceTrusted(String deviceId) {
    return _pairedDevices.containsKey(deviceId) && (_pairedDevices[deviceId]?.isPaired ?? false);
  }

  /// Save or update a paired device
  Future<void> addOrUpdatePairedDevice(DeviceModel device) async {
    final updated = device.copyWith(isPaired: true);
    _pairedDevices[device.id] = updated;
    await _persist();
  }

  /// Remove a device from paired list (Unpair)
  Future<void> unpairDevice(String deviceId) async {
    _pairedDevices.remove(deviceId);
    await _persist();
  }

  /// Get paired device metadata by ID
  DeviceModel? getDevice(String deviceId) => _pairedDevices[deviceId];

  Future<void> _persist() async {
    final list = _pairedDevices.values.map((d) => d.toJson()).toList();
    await _storage.write(key: AppConstants.keyPairedDevices, value: jsonEncode(list));
  }
}
