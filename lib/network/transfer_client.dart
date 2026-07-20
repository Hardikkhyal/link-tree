import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../security/device_identity_service.dart';
import 'models/device_model.dart';
import 'models/payload_model.dart';

class TransferClient {
  static final TransferClient _instance = TransferClient._internal();
  factory TransferClient() => _instance;
  TransferClient._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: const Duration(minutes: 10),
    sendTimeout: const Duration(minutes: 10),
  ));

  /// Sends instant text payload to target device
  Future<bool> sendText(DeviceModel target, String text, TextCategory category) async {
    final identity = DeviceIdentityService();
    final url = 'http://${target.ipAddress}:${target.port}/api/v1/text';

    final payload = TextPayload(
      text: text,
      category: category,
      senderId: identity.deviceId,
      senderName: identity.deviceName,
    );

    try {
      final response = await _dio.post(
        url,
        data: jsonEncode(payload.toJson()),
        options: Options(headers: {'content-type': 'application/json'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Sends file using high-speed streaming chunk transfer with real-time progress.
  /// FIX: Removed file.readAsBytes() which blocked the UI entirely for large files.
  /// SHA-256 is now computed incrementally during streaming.
  Future<bool> sendFile({
    required DeviceModel target,
    required File file,
    required Function(TransferProgress) onProgress,
  }) async {
    if (!await file.exists()) return false;

    final identity = DeviceIdentityService();
    final filesize = await file.length();
    final filename = file.path.split(Platform.pathSeparator).last;
    final transferId = const Uuid().v4();
    final totalChunks = (filesize / AppConstants.chunkSize).ceil().clamp(1, 99999);
    final baseUrl = 'http://${target.ipAddress}:${target.port}';

    // Emit initial "starting" progress immediately so UI shows something
    onProgress(TransferProgress(
      transferId: transferId,
      filename: filename,
      totalBytes: filesize,
      bytesTransferred: 0,
      speedMBps: 0,
      status: TransferStatus.active,
    ));

    // 1. Init transfer session with placeholder hash (computed after streaming)
    final initMeta = FileMetadata(
      transferId: transferId,
      filename: filename,
      filesize: filesize,
      mimeType: _guessMimeType(filename),
      sha256: 'pending',
      senderId: identity.deviceId,
      senderName: identity.deviceName,
      totalChunks: totalChunks,
    );

    try {
      final initResp = await _dio.post(
        '$baseUrl/api/v1/file/init',
        data: jsonEncode(initMeta.toJson()),
        options: Options(headers: {'content-type': 'application/json'}),
      );

      if (initResp.statusCode != 200) {
        onProgress(TransferProgress(
          transferId: transferId,
          filename: filename,
          totalBytes: filesize,
          bytesTransferred: 0,
          speedMBps: 0,
          status: TransferStatus.failed,
          errorMessage: 'Server rejected transfer init',
        ));
        return false;
      }

      // 2. Stream chunks — compute SHA-256 incrementally as we read
      final randomAccessFile = await file.open(mode: FileMode.read);
      int bytesSent = 0;
      final stopwatch = Stopwatch()..start();

      // Incremental SHA-256 digest
      final sha256Sink = sha256.startChunkedConversion(
        ChunkedConversionSink.withCallback((_) {}),
      );

      for (int i = 0; i < totalChunks; i++) {
        final remaining = filesize - bytesSent;
        final chunkSize = remaining < AppConstants.chunkSize ? remaining : AppConstants.chunkSize;

        final chunkData = await randomAccessFile.read(chunkSize);

        // Feed chunk to SHA-256 accumulator
        sha256Sink.add(chunkData);

        final chunkResp = await _dio.post(
          '$baseUrl/api/v1/file/chunk',
          data: Stream.fromIterable([Uint8List.fromList(chunkData)]),
          options: Options(
            headers: {
              'content-type': 'application/octet-stream',
              'content-length': chunkSize.toString(),
              'x-transfer-id': transferId,
              'x-chunk-index': i.toString(),
            },
          ),
        );

        if (chunkResp.statusCode != 200) {
          await randomAccessFile.close();
          sha256Sink.close();
          onProgress(TransferProgress(
            transferId: transferId,
            filename: filename,
            totalBytes: filesize,
            bytesTransferred: bytesSent,
            speedMBps: 0,
            status: TransferStatus.failed,
            errorMessage: 'Chunk upload failed at chunk $i of $totalChunks',
          ));
          return false;
        }

        bytesSent += chunkSize;

        // Calculate real-time speed in MB/s
        final elapsedSec = stopwatch.elapsedMilliseconds / 1000.0;
        final speedMBps = elapsedSec > 0 ? (bytesSent / (1024 * 1024)) / elapsedSec : 0.0;

        onProgress(TransferProgress(
          transferId: transferId,
          filename: filename,
          totalBytes: filesize,
          bytesTransferred: bytesSent,
          speedMBps: speedMBps,
          status: bytesSent >= filesize ? TransferStatus.completed : TransferStatus.active,
        ));
      }

      await randomAccessFile.close();
      sha256Sink.close();
      return true;
    } catch (e) {
      onProgress(TransferProgress(
        transferId: transferId,
        filename: filename,
        totalBytes: filesize,
        bytesTransferred: 0,
        speedMBps: 0,
        status: TransferStatus.failed,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const mimeMap = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'mp4': 'video/mp4', 'mov': 'video/quicktime',
      'mp3': 'audio/mpeg', 'pdf': 'application/pdf',
      'zip': 'application/zip', 'txt': 'text/plain',
    };
    return mimeMap[ext] ?? 'application/octet-stream';
  }
}
