import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class PlatformService with TrayListener {
  static final PlatformService _instance = PlatformService._internal();
  factory PlatformService() => _instance;
  PlatformService._internal();

  final _sharedFilesController = StreamController<List<SharedMediaFile>>.broadcast();
  Stream<List<SharedMediaFile>> get sharedFilesStream => _sharedFilesController.stream;

  Future<void> init() async {
    // 1. Desktop Window Manager
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.ensureInitialized();
      final windowOptions = const WindowOptions(
        size: Size(1100, 750),
        minimumSize: Size(850, 600),
        center: true,
        backgroundColor: Color(0xFF0F172A),
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'HK Drop - Effortless Device Companion',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });

      // System Tray Menu Setup
      try {
        await trayManager.setIcon(
          Platform.isWindows ? 'assets/icons/app_icon.ico' : 'assets/icons/app_icon.png',
        );
        final Menu menu = Menu(
          items: [
            MenuItem(id: 'show_window', label: 'Open HK Drop'),
            MenuItem.separator(),
            MenuItem(id: 'exit_app', label: 'Quit'),
          ],
        );
        await trayManager.setContextMenu(menu);
        trayManager.addListener(this);
      } catch (_) {}
    }

    // 2. Android Share Sheet Intent Receiver
    if (!kIsWeb && Platform.isAndroid) {
      // For sharing images, videos, text, files while app is running in background or closed
      ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _sharedFilesController.add(value);
        }
      });

      ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
        if (value.isNotEmpty) {
          _sharedFilesController.add(value);
        }
      });
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.id == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.id == 'exit_app') {
      exit(0);
    }
  }
}
