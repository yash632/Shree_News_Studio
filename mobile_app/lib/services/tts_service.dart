import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TtsService {
  static const String trustedClientToken = "6A5AA1D4EA6540818300808F2A3B8E45";
  static const String wssUrl =
      "wss://speech.platform.bing.com/consumer/speech/synthesize/readaheadedge/v1?TrustedClientToken=$trustedClientToken";

  /// Synthesizes neural Hindi speech directly via Microsoft Edge TTS WebSocket.
  /// No API key or third-party packages required.
  static Future<String> generateSpeech({
    required String text,
    String voice = 'hi-IN-MadhurNeural',
    double speed = 1.0,
    String? backendUrl,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('TTS text cannot be empty.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFile = File('${tempDir.path}/tts_$timestamp.mp3');

    // 1. If backend URL is provided or reachable, try backend API first
    if (backendUrl != null && backendUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('$backendUrl/api/preview-voice');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'voice': voice,
            'speed': speed,
          }),
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['success'] == true && data['audio_url'] != null) {
            String audioUrl = data['audio_url'];
            if (!audioUrl.startsWith('http')) {
              audioUrl = '$backendUrl$audioUrl';
            }
            final audioRes = await http.get(Uri.parse(audioUrl));
            if (audioRes.statusCode == 200 && audioRes.bodyBytes.length > 500) {
              await outputFile.writeAsBytes(audioRes.bodyBytes);
              return outputFile.path;
            }
          }
        }
      } catch (_) {
        // Fall back to direct Edge TTS WebSocket
      }
    }

    // 2. Direct Microsoft Edge TTS Neural WebSocket
    String rateStr = '+0%';
    if (speed != 1.0) {
      final pct = ((speed - 1.0) * 100).round();
      rateStr = pct >= 0 ? '+$pct%' : '$pct%';
    }

    final completer = Completer<String>();
    final audioChunks = <int>[];

    try {
      final socket = await WebSocket.connect(
        wssUrl,
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
        },
      ).timeout(const Duration(seconds: 10));

      final reqId = DateTime.now().millisecondsSinceEpoch.toString();

      // Step A: Send Speech Config
      const configMsg =
          "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n"
          '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-96kbitrate-mono-mp3"}}}}';
      socket.add(configMsg);

      // Step B: Send SSML
      final ssml =
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='hi-IN'>"
          "<voice name='$voice'><prosody rate='$rateStr'>${_escapeXml(text)}</prosody></voice></speak>";

      final ssmlMsg =
          "X-RequestId:$reqId\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n$ssml";
      socket.add(ssmlMsg);

      // Step C: Listen for Audio Binary Packets
      socket.listen(
        (data) {
          if (data is List<int>) {
            // Binary audio chunk
            final bytes = Uint8List.fromList(data);
            if (bytes.length > 2) {
              final headerLen = (bytes[0] << 8) | bytes[1];
              if (bytes.length > headerLen + 2) {
                final audioData = bytes.sublist(headerLen + 2);
                audioChunks.addAll(audioData);
              }
            }
          } else if (data is String) {
            if (data.contains("Path:turn.end")) {
              socket.close();
              if (audioChunks.isNotEmpty) {
                outputFile.writeAsBytes(audioChunks).then((_) {
                  completer.complete(outputFile.path);
                });
              } else {
                completer.completeError(Exception("No audio bytes received from Edge-TTS."));
              }
            }
          }
        },
        onError: (err) {
          if (!completer.isCompleted) completer.completeError(err);
        },
        onDone: () {
          if (!completer.isCompleted) {
            if (audioChunks.isNotEmpty) {
              outputFile.writeAsBytes(audioChunks).then((_) {
                completer.complete(outputFile.path);
              });
            } else {
              completer.completeError(Exception("WebSocket closed before audio completed."));
            }
          }
        },
      );
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Edge TTS Connection Failed: $e"));
      }
    }

    return completer.future.timeout(const Duration(seconds: 30));
  }

  static String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
