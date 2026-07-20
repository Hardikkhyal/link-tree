import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../network/discovery_service.dart';
import '../../network/models/device_model.dart';
import '../../network/models/payload_model.dart';
import '../../network/transfer_client.dart';
import '../../network/transfer_server.dart';
import '../../security/device_identity_service.dart';
import '../../security/trust_store.dart';
import '../../services/text_sharing_service.dart';
import '../widgets/device_card.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/radar_view.dart';
import 'pairing_screen.dart';
import 'text_popup_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscoveryService _discoveryService = DiscoveryService();
  final TransferServer _transferServer = TransferServer();
  final TransferClient _transferClient = TransferClient();
  final TrustStore _trustStore = TrustStore();

  List<DeviceModel> _discoveredDevices = [];
  final List<TransferProgress> _activeProgressList = [];
  String _localIp = '127.0.0.1';

  final TextEditingController _textShareController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initServices();
  }

  Future<void> _initServices() async {
    final ip = await _discoveryService.getLocalIpAddress();
    if (mounted) setState(() => _localIp = ip ?? '127.0.0.1');

    // Subscribe to mDNS discovered devices
    _discoveryService.devicesStream.listen((devices) {
      if (mounted) setState(() => _discoveredDevices = devices);
    });

    // Subscribe to incoming text payloads
    _transferServer.textReceivedStream.listen((textPayload) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => TextPopupDialog(payload: textPayload),
        );
      }
    });

    // Subscribe to incoming file transfer progress
    _transferServer.fileProgressStream.listen((progress) {
      if (mounted) {
        setState(() {
          final idx = _activeProgressList.indexWhere((p) => p.transferId == progress.transferId);
          if (idx >= 0) {
            _activeProgressList[idx] = progress;
          } else {
            _activeProgressList.add(progress);
          }
        });
      }
    });

    await _discoveryService.startBroadcasting();
    await _discoveryService.startDiscovery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textShareController.dispose();
    super.dispose();
  }

  void _sendFilesToDevice(DeviceModel target, List<File> files) async {
    for (var file in files) {
      await _transferClient.sendFile(
        target: target,
        file: file,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              final idx = _activeProgressList.indexWhere((p) => p.transferId == progress.transferId);
              if (idx >= 0) {
                _activeProgressList[idx] = progress;
              } else {
                _activeProgressList.add(progress);
              }
            });
          }
        },
      );
    }
  }

  void _pickAndSendFiles(DeviceModel target) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.files.isNotEmpty) {
      final files = result.files.where((f) => f.path != null).map((f) => File(f.path!)).toList();
      _sendFilesToDevice(target, files);
    }
  }

  void _showTextShareModal(DeviceModel target) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Share Text to ${target.name}'),
        content: TextField(
          controller: _textShareController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Enter link, note, or code snippet...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              final text = _textShareController.text.trim();
              if (text.isNotEmpty) {
                final category = TextSharingService.detectCategory(text);
                final ok = await _transferClient.sendText(target, text, category);
                _textShareController.clear();
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Text Shared!' : 'Failed to Share Text'),
                      backgroundColor: ok ? AppTheme.accent : AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Instant'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = DeviceIdentityService();
    final pairedDevices = _trustStore.pairedDevices;

    return Scaffold(
      body: DesktopDropZone(
        onFilesDropped: (files) {
          if (pairedDevices.isNotEmpty) {
            _sendFilesToDevice(pairedDevices.first, files);
          } else if (_discoveredDevices.isNotEmpty) {
            _sendFilesToDevice(_discoveredDevices.first, files);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active devices found to receive files.')),
            );
          }
        },
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.8),
                border: const Border(bottom: BorderSide(color: Colors.white10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horizontal_circle_rounded, color: AppTheme.primary, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAlignment.start,
                    children: [
                      const Text(
                        'HK Drop',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      Text(
                        '${identity.deviceName} • $_localIp',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () async {
                      await showDialog(context: context, builder: (_) => const PairingScreen());
                      setState(() {});
                    },
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    label: const Text('Pair Device'),
                  ),
                ],
              ),
            ),

            // Navigation Tabs
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Radar Discovery', icon: Icon(Icons.radar_rounded)),
                Tab(text: 'Paired Devices', icon: Icon(Icons.devices_rounded)),
                Tab(text: 'Transfers History', icon: Icon(Icons.sync_alt_rounded)),
              ],
            ),

            // Main Content Area
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Radar View
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text(
                          'Scanning Local Network for Nearby Devices...',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: RadarView(
                            devices: _discoveredDevices,
                            onDeviceTap: (device) {
                              _pickAndSendFiles(device);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Paired Devices List
                  ListView(
                    padding: const EdgeInsets.all(24),
                    children: pairedDevices.isEmpty
                        ? [
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Text(
                                  'No Paired Devices Yet.\nTap "Pair Device" above to connect your Phone and Laptop.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
                                ),
                              ),
                            ),
                          ]
                        : pairedDevices.map((d) {
                            return DeviceCard(
                              device: d,
                              onSendFile: () => _pickAndSendFiles(d),
                              onSendText: () => _showTextShareModal(d),
                              onUnpair: () async {
                                await _trustStore.unpairDevice(d.id);
                                setState(() {});
                              },
                            );
                          }).toList(),
                  ),

                  // Tab 3: Transfer History & Active Transfers
                  ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _activeProgressList.length,
                    itemBuilder: (context, idx) {
                      final item = _activeProgressList[idx];
                      return GlassCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item.filename,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.speedMBps.toStringAsFixed(1)} MB/s',
                                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: item.progressPercentage,
                              backgroundColor: Colors.white10,
                              color: item.status == TransferStatus.completed ? AppTheme.accent : AppTheme.primary,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(item.bytesTransferred / (1024 * 1024)).toStringAsFixed(1)} MB / ${(item.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                Text(
                                  item.status.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: item.status == TransferStatus.completed ? AppTheme.accent : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
