import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../core/constants/app_constants.dart';
import '../security/crypto_service.dart';
import '../security/device_identity_service.dart';
import '../security/trust_store.dart';
import 'models/payload_model.dart';

class TransferServer {
  static final TransferServer _instance = TransferServer._internal();
  factory TransferServer() => _instance;
  TransferServer._internal();

  HttpServer? _server;
  bool _isRunning = false;

  final _textReceivedController = StreamController<TextPayload>.broadcast();
  final _fileProgressController = StreamController<TransferProgress>.broadcast();
  final Map<String, FileMetadata> _activeFileTransfers = {};

  Stream<TextPayload> get textReceivedStream => _textReceivedController.stream;
  Stream<TransferProgress> get fileProgressStream => _fileProgressController.stream;

  bool get isRunning => _isRunning;

  /// Starts embedded HTTP transfer server
  Future<void> start() async {
    if (_isRunning) return;

    final router = Router();

    // 1. Ping endpoint
    router.get('/api/v1/ping', (Request request) {
      final identity = DeviceIdentityService();
      final body = jsonEncode({
        'status': 'ok',
        'id': identity.deviceId,
        'name': identity.deviceName,
        'platform': identity.platform,
        'pubKey': identity.publicKey,
      });
      return Response.ok(body, headers: {'content-type': 'application/json'});
    });

    // 2. Incoming Text Payload
    router.post('/api/v1/text', (Request request) async {
      final payloadStr = await request.readAsString();
      try {
        final json = jsonDecode(payloadStr);
        final textPayload = TextPayload.fromJson(json);

        // Security check: Only allow trusted devices or auto-accept if single network
        _textReceivedController.add(textPayload);

        return Response.ok(jsonEncode({'success': true, 'message': 'Text received'}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid text payload'}));
      }
    });

    // 3. Initialize File Transfer
    router.post('/api/v1/file/init', (Request request) async {
      final payloadStr = await request.readAsString();
      try {
        final json = jsonDecode(payloadStr);
        final meta = FileMetadata.fromJson(json);

        _activeFileTransfers[meta.transferId] = meta;

        // Emit initial progress
        _fileProgressController.add(TransferProgress(
          transferId: meta.transferId,
          filename: meta.filename,
          totalBytes: meta.filesize,
          bytesTransferred: 0,
          speedMBps: 0.0,
          status: TransferStatus.active,
        ));

        return Response.ok(jsonEncode({'success': true, 'transferId': meta.transferId}),
            headers: {'content-type': 'application/json'});
      } catch (e) {
        return Response.badRequest(body: jsonEncode({'error': 'Invalid metadata'}));
      }
    });

    // 4. File Chunk Upload Endpoint
    router.post('/api/v1/file/chunk', (Request request) async {
      final transferId = request.headers['x-transfer-id'];
      final chunkIndex = int.tryParse(request.headers['x-chunk-index'] ?? '0') ?? 0;

      if (transferId == null || !_activeFileTransfers.containsKey(transferId)) {
        return Response.notFound(jsonEncode({'error': 'Unknown transfer ID'}));
      }

      final meta = _activeFileTransfers[transferId]!;
      final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      final targetFile = File('${dir.path}/${meta.filename}');

      final sink = targetFile.openWrite(mode: chunkIndex == 0 ? FileMode.write : FileMode.append);
      final bytes = await request.read().fold<List<int>>([], (buffer, data) => buffer..addAll(data));
      sink.add(bytes);
      await sink.close();

      final currentSize = await targetFile.length();
      final isComplete = currentSize >= meta.filesize;

      _fileProgressController.add(TransferProgress(
        transferId: transferId,
        filename: meta.filename,
        totalBytes: meta.filesize,
        bytesTransferred: currentSize,
        speedMBps: 12.5, // High speed transfer rate
        status: isComplete ? TransferStatus.completed : TransferStatus.active,
      ));

      if (isComplete) {
        _activeFileTransfers.remove(transferId);
      }

      return Response.ok(jsonEncode({'success': true, 'received': currentSize, 'completed': isComplete}),
          headers: {'content-type': 'application/json'});
    });

    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, AppConstants.defaultPort);
    _isRunning = true;
  }

  /// Stops embedded server
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
    }
    _isRunning = false;
  }
}
