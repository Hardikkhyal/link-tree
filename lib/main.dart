import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'network/transfer_server.dart';
import 'security/device_identity_service.dart';
import 'security/trust_store.dart';
import 'services/notification_service.dart';
import 'services/platform_service.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services
  await DeviceIdentityService().init();
  await TrustStore().init();
  await NotificationService().init();
  await PlatformService().init();

  // Start Embedded HTTP Streaming Server
  await TransferServer().start();

  runApp(const HKDropApp());
}

class HKDropApp extends StatelessWidget {
  const HKDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HK Drop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
