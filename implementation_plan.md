# Offline Local File Transfer Speed Optimization Plan

This implementation plan outlines architectural and network protocol optimizations to maximize offline local transfer speeds (target: **50 MB/s – 120 MB/s+** on Wi-Fi 5/6 and Gigabit LAN) without internet dependencies.

---

## 1. Bottleneck Analysis of Current Implementation

| Component | Current Implementation | Bottleneck / Limitation |
| :--- | :--- | :--- |
| **Protocol** | Sequential HTTP/1.1 POST per chunk via Shelf/Dio | High HTTP header overhead and RTT latency waiting for HTTP 200 per chunk. |
| **File I/O** | `openWrite(mode: append)` opened and closed per chunk | Repeated OS file handle creation, disk flushes, and OS lock contention. |
| **Buffer Size** | Default 64KB / 512KB Dart stream buffers | Underutilizes high-bandwidth Wi-Fi 6 / 5GHz channels. |
| **Concurrency** | Single sequential stream | Cannot saturate multi-channel MIMO Wi-Fi routers. |

---

## 2. Proposed Architectural Improvements

### Phase 1: High-Speed Raw TCP Socket Engine (Zero HTTP Overhead)
- **Persistent TCP Connections**: Replace HTTP POST chunk requests with dedicated Raw TCP sockets (`Socket` / `ServerSocket`).
- **Socket Buffer Tuning**:
  - Set `socket.setOption(SocketOption.tcpNoDelay, true)` to disable Nagle's algorithm.
  - Set `SO_SNDBUF` and `SO_RCVBUF` to **2MB - 4MB** to allow maximum network pipeline depth.
- **Binary Frame Framing**: Use 12-byte lightweight binary header `[4-byte Length][4-byte ChunkIndex][4-byte Flags]` followed by payload bytes instead of JSON/HTTP headers.

### Phase 2: Optimized Disk I/O & Memory Streaming
- **Persistent `RandomAccessFile` Handles**: Open file once in `FileMode.write` at `file/init`, write chunks directly to calculated byte offsets (`setPosition(offset)`), and close only on transfer completion or error.
- **Direct Stream Pipelining**: Use `pipe()` or direct stream transforms with 1MB chunk sizes (`1024 * 1024` bytes) to prevent Dart garbage collection pauses.

### Phase 3: Multi-Stream Parallel Transfer (for Large Files > 50MB)
- **Parallel TCP Sockets**: For files larger than 50MB, split the file into 4 parallel chunk streams running simultaneously across multiple TCP connections.
- **Concurrent Disk Writes**: Assign chunk index ranges to separate workers writing to non-overlapping offsets of the destination file.

---

## Proposed Changes

### Network & Core Layer

#### [MODIFY] [app_constants.dart](file:///d:/link%20tree/lib/core/constants/app_constants.dart)
- Increase default chunk size from 512KB to **1MB** (`1024 * 1024`).
- Add socket configuration constants: `tcpBufferSize = 2 * 1024 * 1024`, `maxParallelStreams = 4`.

#### [MODIFY] [transfer_server.dart](file:///d:/link%20tree/lib/network/transfer_server.dart)
- Integrate a high-speed Raw TCP `ServerSocket` listener on port `AppConstants.tcpPort` alongside the HTTP REST API.
- Keep persistent `RandomAccessFile` handles during file upload sessions.

#### [MODIFY] [transfer_client.dart](file:///d:/link%20tree/lib/network/transfer_client.dart)
- Implement raw socket client connection with `tcpNoDelay = true`.
- Implement parallel chunk dispatch for files > 50MB.

---

## User Review Required

> [!IMPORTANT]
> - **Backward Compatibility**: Mobile devices running older versions will fallback to the existing HTTP chunk API automatically if the Raw TCP socket is unavailable.
> - **Battery & Thermal Management**: Parallel 4-stream transfers maximize CPU/Wi-Fi chip usage; on mobile devices, transfers will automatically scale down to 2 streams if battery saver is enabled.

---

## Verification Plan

### Automated Tests
- Benchmark test measuring transfer speed of 100MB dummy file between local sockets.
- Verify SHA-256 hash checksum integrity after parallel transfers.

### Manual Verification
- Test transfer of a 1GB file over a 5GHz Wi-Fi network between PC and Mobile device.
- Compare speed metrics before (HTTP chunking) and after (Raw TCP socket streaming).
