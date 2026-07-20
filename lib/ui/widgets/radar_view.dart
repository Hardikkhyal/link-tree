import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../network/models/device_model.dart';

class RadarView extends StatefulWidget {
  final List<DeviceModel> devices;
  final Function(DeviceModel) onDeviceTap;

  const RadarView({
    super.key,
    required this.devices,
    required this.onDeviceTap,
  });

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = min(constraints.maxWidth, constraints.maxHeight);
      final center = size / 2;

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse Circles
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size(size, size),
                    painter: RadarPainter(progress: _controller.value),
                  );
                },
              ),

              // Center Pulse Node (Self)
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_tethering_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ).animate(onPlay: (controller) => controller.repeat(reverse: true))
               .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.08, 1.08), duration: 1200.ms),

              // Orbiting Discovered Devices
              ...widget.devices.asMap().entries.map((entry) {
                final idx = entry.key;
                final device = entry.value;

                final angle = (2 * pi / max(1, widget.devices.length)) * idx + (pi / 4);
                final radius = center * 0.65;
                final dx = center + radius * cos(angle) - 30;
                final dy = center + radius * sin(angle) - 30;

                final isMobile = device.deviceType == DeviceType.mobile;

                return Positioned(
                  left: dx,
                  top: dy,
                  child: GestureDetector(
                    onTap: () => widget.onDeviceTap(device),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: device.isPaired ? AppTheme.accent.withOpacity(0.25) : AppTheme.surface,
                            border: Border.all(
                              color: device.isPaired ? AppTheme.accent : AppTheme.primary,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (device.isPaired ? AppTheme.accent : AppTheme.primary).withOpacity(0.4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: Icon(
                            isMobile ? Icons.phone_android_rounded : Icons.laptop_mac_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            device.name,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    });
  }
}

class RadarPainter extends CustomPainter {
  final double progress;

  RadarPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw 3 static background grid rings
    for (int i = 1; i <= 3; i++) {
      paint.color = Colors.white.withOpacity(0.06);
      canvas.drawCircle(center, maxRadius * (i / 3), paint);
    }

    // Draw expanding pulse animation
    final currentRadius = maxRadius * progress;
    final pulseOpacity = (1.0 - progress).clamp(0.0, 1.0);
    paint.color = AppTheme.primary.withOpacity(pulseOpacity * 0.4);
    paint.strokeWidth = 2.0;
    canvas.drawCircle(center, currentRadius, paint);
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => oldDelegate.progress != progress;
}
