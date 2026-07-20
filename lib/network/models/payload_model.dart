enum PayloadType { text, file }
enum TextCategory { link, note, code, otp, clipboard }
enum TransferStatus { pending, active, completed, failed, cancelled }

class TextPayload {
  final String text;
  final TextCategory category;
  final String senderId;
  final String senderName;
  final DateTime timestamp;

  TextPayload({
    required this.text,
    required this.category,
    required this.senderId,
    required this.senderName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': 'text',
      'text': text,
      'category': category.name,
      'senderId': senderId,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TextPayload.fromJson(Map<String, dynamic> json) {
    return TextPayload(
      text: json['text'] as String,
      category: TextCategory.values.firstWhere(
        (c) => c.name == (json['category'] as String? ?? 'note'),
        orElse: () => TextCategory.note,
      ),
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp'] as String) : DateTime.now(),
    );
  }
}

class FileMetadata {
  final String transferId;
  final String filename;
  final int filesize;
  final String mimeType;
  final String sha256;
  final String senderId;
  final String senderName;
  final int totalChunks;

  FileMetadata({
    required this.transferId,
    required this.filename,
    required this.filesize,
    required this.mimeType,
    required this.sha256,
    required this.senderId,
    required this.senderName,
    required this.totalChunks,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': 'file',
      'transferId': transferId,
      'filename': filename,
      'filesize': filesize,
      'mimeType': mimeType,
      'sha256': sha256,
      'senderId': senderId,
      'senderName': senderName,
      'totalChunks': totalChunks,
    };
  }

  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      transferId: json['transferId'] as String,
      filename: json['filename'] as String,
      filesize: json['filesize'] as int,
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
      sha256: json['sha256'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      totalChunks: json['totalChunks'] as int? ?? 1,
    );
  }
}

class TransferProgress {
  final String transferId;
  final String filename;
  final int totalBytes;
  final int bytesTransferred;
  final double speedMBps;
  final TransferStatus status;
  final String? errorMessage;

  TransferProgress({
    required this.transferId,
    required this.filename,
    required this.totalBytes,
    required this.bytesTransferred,
    required this.speedMBps,
    required this.status,
    this.errorMessage,
  });

  double get progressPercentage => totalBytes > 0 ? (bytesTransferred / totalBytes).clamp(0.0, 1.0) : 0.0;
}
