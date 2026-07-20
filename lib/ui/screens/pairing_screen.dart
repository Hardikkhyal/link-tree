import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../security/pairing_service.dart';
import '../widgets/glass_card.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  PairingPayload? _myPayload;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPayload();
  }

  Future<void> _loadPayload() async {
    final payload = await PairingService().generateMyPairingPayload();
    setState(() {
      _myPayload = payload;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderColor: AppTheme.primary,
        child: SizedBox(
          width: 440,
          height: 520,
          child: Column(
            children: [
              // Header & Close Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pair Device (1-Time Setup)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primary,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(text: 'My QR Code', icon: Icon(Icons.qr_code_rounded)),
                  Tab(text: 'Scan QR', icon: Icon(Icons.qr_code_scanner_rounded)),
                ],
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Show My QR
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: QrImageView(
                                    data: _myPayload!.toRawString(),
                                    version: QrVersions.auto,
                                    size: 220.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Scan with mobile camera or HK Drop app',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'IP: ${_myPayload!.ipAddress}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          ),

                    // Tab 2: Camera Scanner
                    MobileScanner(
                      onDetect: (capture) async {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            final success = await PairingService().processPairingQR(barcode.rawValue!);
                            if (mounted) {
                              Navigator.of(context).pop(success);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(success ? 'Device Paired Successfully!' : 'Pairing Failed!'),
                                  backgroundColor: success ? AppTheme.accent : AppTheme.danger,
                                ),
                              );
                              break;
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
