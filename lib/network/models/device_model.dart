enum DeviceType { mobile, desktop, unknown }

class DeviceModel {
  final String id;
  final String name;
  final String platform; // "android", "ios", "windows", "macos", "linux"
  final String ipAddress;
  final int port;
  final String publicKey;
  final bool isPaired;
  final DateTime lastSeen;

  DeviceModel({
    required this.id,
    required this.name,
    required this.platform,
    required this.ipAddress,
    required this.port,
    required this.publicKey,
    this.isPaired = false,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  DeviceType get deviceType {
    final p = platform.toLowerCase();
    if (p == 'android' || p == 'ios') return DeviceType.mobile;
    if (p == 'windows' || p == 'macos' || p == 'linux') return DeviceType.desktop;
    return DeviceType.unknown;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'ipAddress': ipAddress,
      'port': port,
      'publicKey': publicKey,
      'isPaired': isPaired,
      'lastSeen': lastSeen.toIso8601String(),
    };
  }

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      platform: json['platform'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int? ?? 45789,
      publicKey: json['publicKey'] as String? ?? '',
      isPaired: json['isPaired'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null ? DateTime.parse(json['lastSeen'] as String) : DateTime.now(),
    );
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? platform,
    String? ipAddress,
    int? port,
    String? publicKey,
    bool? isPaired,
    DateTime? lastSeen,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      publicKey: publicKey ?? this.publicKey,
      isPaired: isPaired ?? this.isPaired,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
