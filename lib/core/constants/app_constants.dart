class AppConstants {
  static const String appName = 'HK Drop';
  static const String appVersion = '1.0.0';

  // Network & Service Discovery Configuration
  static const int defaultPort = 45789;
  static const String mdnsServiceType = '_hkdrop._tcp';
  static const String mdnsDomain = 'local.';

  // Storage Keys
  static const String keyDeviceId = 'hkdrop_device_id';
  static const String keyDeviceName = 'hkdrop_device_name';
  static const String keyPublicKey = 'hkdrop_public_key';
  static const String keyPrivateKey = 'hkdrop_private_key';
  static const String keyPairedDevices = 'hkdrop_paired_devices_v1';

  // File Transfer Settings
  static const int chunkSize = 512 * 1024; // 512 KB per chunk
  static const int maxRetryAttempts = 5;
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration requestTimeout = Duration(seconds: 30);
}
