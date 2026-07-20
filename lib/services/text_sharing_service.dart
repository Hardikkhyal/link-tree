import 'package:flutter/services.dart';
import '../network/models/payload_model.dart';

class TextSharingService {
  static final TextSharingService _instance = TextSharingService._internal();
  factory TextSharingService() => _instance;
  TextSharingService._internal();

  /// Analyzes text content and categorizes it
  static TextCategory detectCategory(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return TextCategory.link;
    }
    final otpRegExp = RegExp(r'^\d{4,8}$');
    if (otpRegExp.hasMatch(trimmed)) {
      return TextCategory.otp;
    }
    if (trimmed.contains('{') || trimmed.contains('}') || trimmed.contains('class ') || trimmed.contains('function ')) {
      return TextCategory.code;
    }
    return TextCategory.note;
  }

  /// Copies text to device OS clipboard
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
