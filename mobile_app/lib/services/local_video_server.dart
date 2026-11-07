import 'dart:io';

class LocalVideoServer {
  static HttpServer? _server;
  static int _port = 0;
  static String? _currentVideoPath;

  static int get port => _port;

  static Future<int> ensureStarted() async {
    if (_server != null) return _port;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest);
    } catch (e) {
      print('LocalVideoServer start error: $e');
    }
    return _port;
  }

  static void setVideoPath(String? path) {
    _currentVideoPath = path;
  }

  static String? get videoUrl {
    if (_port == 0 || _currentVideoPath == null || !File(_currentVideoPath!).existsSync()) {
      return null;
    }
    return 'http://127.0.0.1:$_port/video.mp4';
  }

  static Future<void> _handleRequest(HttpRequest request) async {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', '*');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    if (_currentVideoPath == null || !File(_currentVideoPath!).existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final file = File(_currentVideoPath!);
      final fileLength = await file.length();
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);

      request.response.headers.add(HttpHeaders.acceptRangesHeader, 'bytes');
      request.response.headers.contentType = ContentType('video', 'mp4');

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        final start = int.tryParse(parts[0]) ?? 0;
        final end = (parts.length > 1 && parts[1].isNotEmpty)
            ? (int.tryParse(parts[1]) ?? (fileLength - 1))
            : (fileLength - 1);

        final safeStart = start.clamp(0, fileLength - 1);
        final safeEnd = end.clamp(safeStart, fileLength - 1);
        final contentLength = safeEnd - safeStart + 1;

        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.add(
          HttpHeaders.contentRangeHeader,
          'bytes $safeStart-$safeEnd/$fileLength',
        );
        request.response.contentLength = contentLength;
        await request.response.addStream(file.openRead(safeStart, safeEnd + 1));
      } else {
        request.response.statusCode = HttpStatus.ok;
        request.response.contentLength = fileLength;
        await request.response.addStream(file.openRead());
      }
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  static void stop() {
    _server?.close(force: true);
    _server = null;
    _port = 0;
  }
}
