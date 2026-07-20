import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../security/crypto_service.dart';
import '../security/device_identity_service.dart';
import 'models/device_model.dart';
import 'models/payload_model.dart';

class TransferClient {
  static final TransferClient _instance = TransferClient._internal();
  factory TransferClient() => _instance;
  TransferClient._internal();

  final _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.requestTimeout,
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

  /// Sends file using high-speed streaming chunk transfer
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
    final totalChunks = (filesize / AppConstants.chunkSize).ceil();

    // Calculate file checksum
    final bytes = await file.readAsBytes();
    final sha256Hash = CryptoService.hashBytes(bytes);

    final baseUrl = 'http://${target.ipAddress}:${target.port}';

    // 1. Init file transfer session
    final initMeta = FileMetadata(
      transferId: transferId,
      filename: filename,
      filesize: filesize,
      mimeType: 'application/octet-stream',
      sha256: sha256Hash,
      senderId: identity.deviceId,
      senderName: identity.deviceName,
      totalChunks: totalChunks,
    );

    try {
      final initResp = await _dio.post(
        '$baseUrl/api/v1/file/init',
        data: jsonEncode(initMeta.toJson()),
      );

      if (initResp.statusCode != 200) return false;

      // 2. Stream File Chunks
      final randomAccessFile = await file.open(mode: FileMode.read);
      int bytesSent = 0;
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < totalChunks; i++) {
        final chunkSize = (i == totalChunks - 1)
            ? filesize - (i * AppConstants.chunkSize)
            : AppConstants.chunkSize;

        final chunkData = await randomAccessFile.read(chunkSize);

        final chunkResp = await _dio.post(
          '$baseUrl/api/v1/file/chunk',
          data: Stream.fromIterable([chunkData]),
          options: Options(
            headers: {
              'content-type': 'application/octet-stream',
              'content-length': chunkSize,
              'x-transfer-id': transferId,
              'x-chunk-index': i,
            },
          ),
        );

        if (chunkResp.statusCode != 200) {
          await randomAccessFile.close();
          onProgress(TransferProgress(
            transferId: transferId,
            filename: filename,
            totalBytes: filesize,
            bytesTransferred: bytesSent,
            speedMBps: 0,
            status: TransferStatus.failed,
            errorMessage: 'Chunk upload failed at index $i',
          ));
          return false;
        }

        bytesSent += chunkSize;

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
}
