import 'dart:async';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants/app_constants.dart';
import '../security/device_identity_service.dart';
import '../security/trust_store.dart';
import 'models/device_model.dart';

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  final Map<String, DeviceModel> _discoveredDevices = {};
  final Map<String, DateTime> _lastSeen = {}; // FIX: track when each device was last seen
  final _discoveredController = StreamController<List<DeviceModel>>.broadcast();

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  Timer? _expiryTimer;

  bool _isBroadcasting = false;
  bool _isDiscovering = false;

  // Device is considered offline if not seen for 30 seconds
  static const _deviceTtl = Duration(seconds: 30);

  Stream<List<DeviceModel>> get devicesStream => _discoveredController.stream;
  List<DeviceModel> get currentDevices => _discoveredDevices.values.toList();

  /// Fetches current local IP address
  Future<String?> getLocalIpAddress() async {
    try {
      final info = NetworkInfo();
      final wifiIp = await info.getWifiIP();
      if (wifiIp != null && wifiIp.isNotEmpty && wifiIp != '0.0.0.0') {
        return wifiIp;
      }
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Start mDNS Broadcast (Advertiser)
  Future<void> startBroadcasting() async {
    if (_isBroadcasting) return;

    final identity = DeviceIdentityService();
    final localIp = await getLocalIpAddress() ?? '127.0.0.1';

    final service = BonsoirService(
      name: 'hkdrop_${identity.deviceId}',
      type: AppConstants.mdnsServiceType,
      port: AppConstants.defaultPort,
      attributes: {
        'id': identity.deviceId,
        'name': identity.deviceName,
        'platform': identity.platform,
        'ip': localIp,
        'pubKey': identity.publicKey,
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.ready;
    await _broadcast!.start();
    _isBroadcasting = true;
  }

  Future<void> stopBroadcasting() async {
    if (_broadcast != null) {
      await _broadcast!.stop();
      _broadcast = null;
    }
    _isBroadcasting = false;
  }

  /// Start Discovery (Browser) with TTL-based ghost device cleanup
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    _discovery = BonsoirDiscovery(type: AppConstants.mdnsServiceType);
    await _discovery!.ready;

    _discovery!.eventStream?.listen((event) {
      if (event.service == null) return;
      final service = event.service!;
      final attrs = service.attributes ?? <String, String>{};
      final id = attrs['id'] ?? service.name;

      final identity = DeviceIdentityService();
      if (id == identity.deviceId) return; // Ignore self

      if (event.type == BonsoirDiscoveryEventType.discoveryServiceFound ||
          event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
        String ipAddress = attrs['ip'] ?? '';
        if (ipAddress.isEmpty && service is ResolvedBonsoirService) {
          ipAddress = service.ip ?? '';
        }

        final device = DeviceModel(
          id: id,
          name: attrs['name'] ?? 'HK Drop Device',
          platform: attrs['platform'] ?? 'unknown',
          ipAddress: ipAddress,
          port: AppConstants.defaultPort,
          publicKey: attrs['pubKey'] ?? '',
          isPaired: TrustStore().isDeviceTrusted(id),
          lastSeen: DateTime.now(),
        );

        _discoveredDevices[id] = device;
        _lastSeen[id] = DateTime.now(); // FIX: update last seen timestamp
        _notify();
      } else if (event.type == BonsoirDiscoveryEventType.discoveryServiceLost) {
        _discoveredDevices.remove(id);
        _lastSeen.remove(id);
        _notify();
      }
    });

    await _discovery!.start();
    _isDiscovering = true;

    // FIX: Start periodic cleanup timer — removes devices not seen in 30s
    _expiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _removeExpiredDevices();
    });

    _scanSubnetFallback();
  }

  /// FIX: Remove devices that haven't been seen within TTL window.
  /// This eliminates ghost devices when a PC is shut down without proper deregistration.
  void _removeExpiredDevices() {
    final now = DateTime.now();
    final expired = _lastSeen.entries
        .where((e) => now.difference(e.value) > _deviceTtl)
        .map((e) => e.key)
        .toList();

    if (expired.isNotEmpty) {
      for (final id in expired) {
        _discoveredDevices.remove(id);
        _lastSeen.remove(id);
      }
      _notify();
    }
  }

  /// Fast local ping scan fallback. Also refreshes lastSeen on confirmed live devices.
  Future<void> _scanSubnetFallback() async {
    final localIp = await getLocalIpAddress();
    if (localIp == null) return;

    final parts = localIp.split('.');
    if (parts.length != 4) return;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    for (int i = 1; i <= 254; i++) {
      final targetIp = '$subnet.$i';
      if (targetIp == localIp) continue;
      _checkDevicePing(targetIp);
    }
  }

  Future<void> _checkDevicePing(String targetIp) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 300);
      final req = await client.get(targetIp, AppConstants.defaultPort, '/api/v1/ping');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        // Refresh lastSeen for this IP if device is already known
        final match = _discoveredDevices.values
            .where((d) => d.ipAddress == targetIp)
            .toList();
        if (match.isNotEmpty) {
          _lastSeen[match.first.id] = DateTime.now();
        }
      }
      await resp.drain();
    } catch (_) {}
  }

  Future<void> stopDiscovery() async {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_discovery != null) {
      await _discovery!.stop();
      _discovery = null;
    }
    _isDiscovering = false;
  }

  void _notify() {
    _discoveredController.add(_discoveredDevices.values.toList());
  }
}
