import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'glass_card.dart';

class DesktopDropZone extends StatefulWidget {
  final Function(List<File>) onFilesDropped;
  final Widget child;

  const DesktopDropZone({
    super.key,
    required this.onFilesDropped,
    required this.child,
  });

  @override
  State<DesktopDropZone> createState() => _DesktopDropZoneState();
}

class _DesktopDropZoneState extends State<DesktopDropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (details) {
        setState(() => _isDragging = true);
      },
      onDragExited: (details) {
        setState(() => _isDragging = false);
      },
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final files = details.files.map((f) => File(f.path)).toList();
        if (files.isNotEmpty) {
          widget.onFilesDropped(files);
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                    borderColor: AppTheme.primary,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.cloud_upload_rounded, size: 64, color: AppTheme.primary),
                        SizedBox(height: 16),
                        Text(
                          'Drop Files to Instant Share',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Selected paired devices will receive the file instantly',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
