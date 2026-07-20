import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/models/payload_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open HK Drop');

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
    _initialized = true;
  }

  /// Show notification when text payload is received
  Future<void> showTextNotification(TextPayload text) async {
    const androidDetails = AndroidNotificationDetails(
      'hkdrop_text_channel',
      'HK Drop Shared Text',
      channelDescription: 'Notifications for incoming text from paired devices',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'HK Drop: Text from ${text.senderName}',
      text.text,
      notificationDetails,
    );
  }

  /// Show notification when file transfer completes
  Future<void> showFileNotification(String filename, String senderName) async {
    const androidDetails = AndroidNotificationDetails(
      'hkdrop_file_channel',
      'HK Drop Received Files',
      channelDescription: 'Notifications for received files',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'HK Drop: File Received',
      '$filename received from $senderName',
      notificationDetails,
    );
  }
}
