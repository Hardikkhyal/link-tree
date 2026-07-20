import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../network/models/device_model.dart';
import 'glass_card.dart';

class DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback onSendFile;
  final VoidCallback onSendText;
  final VoidCallback? onUnpair;

  const DeviceCard({
    super.key,
    required this.device,
    required this.onSendFile,
    required this.onSendText,
    this.onUnpair,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = device.deviceType == DeviceType.mobile;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: device.isPaired ? AppTheme.accent.withOpacity(0.4) : Colors.white10,
      child: Row(
        children: [
          // Platform Avatar Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: device.isPaired ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceLight,
              border: Border.all(
                color: device.isPaired ? AppTheme.accent : AppTheme.primary,
                width: 1.5,
              ),
            ),
            child: Icon(
              isMobile ? Icons.phone_android_rounded : Icons.laptop_mac_rounded,
              color: device.isPaired ? AppTheme.accent : AppTheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Device Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (device.isPaired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accent, width: 0.8),
                        ),
                        child: const Text(
                          'PAIRED',
                          style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.platform.toUpperCase()} • ${device.ipAddress}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Action Buttons
          IconButton(
            onPressed: onSendText,
            icon: const Icon(Icons.short_text_rounded, color: AppTheme.primary),
            tooltip: 'Share Text / Link',
          ),
          IconButton(
            onPressed: onSendFile,
            icon: const Icon(Icons.send_rounded, color: AppTheme.secondary),
            tooltip: 'Send File',
          ),
          if (onUnpair != null)
            IconButton(
              onPressed: onUnpair,
              icon: const Icon(Icons.link_off_rounded, color: AppTheme.danger),
              tooltip: 'Unpair Device',
            ),
        ],
      ),
    );
  }
}
