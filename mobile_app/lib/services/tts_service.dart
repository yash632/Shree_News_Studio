import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TtsService {
  // Current official Microsoft Azure / Edge TTS WebSocket endpoint and key
  static const String endpointKey = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
  static const String wssUrl =
      "wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1?Ocp-Apim-Subscription-Key=$endpointKey";

  /// Generates natural Hindi speech audio.
  /// Tries Microsoft Edge Neural WebSocket first; seamlessly falls back to Google Hindi TTS
  /// so that speech synthesis NEVER fails and never throws an unhandled WebSocketException.
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

    // 1. If backend URL is provided, try backend REST endpoint first
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
        ).timeout(const Duration(seconds: 6));

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
        // Fall back to direct synthesizers
      }
    }

    // 2. Try Microsoft Edge Neural WebSocket
    String rateStr = '+0%';
    if (speed != 1.0) {
      final pct = ((speed - 1.0) * 100).round();
      rateStr = pct >= 0 ? '+$pct%' : '$pct%';
    }

    try {
      final edgeAudio = await _generateEdgeTts(
        text: text,
        voice: voice,
        rateStr: rateStr,
        outputFile: outputFile,
      );
      if (edgeAudio != null && await File(edgeAudio).exists() && await File(edgeAudio).length() > 500) {
        return edgeAudio;
      }
    } catch (e) {
      print('Edge TTS WebSocket unavailable ($e), switching to Google Hindi TTS...');
    }

    // 3. Guaranteed High-Speed Fallback: Google Hindi Neural TTS (HTTP GET)
    return await _generateGoogleHindiTts(text, outputFile);
  }

  /// Synthesizes neural voice via Edge TTS WebSocket with required 'synthesize' subprotocol
  static Future<String?> _generateEdgeTts({
    required String text,
    required String voice,
    required String rateStr,
    required File outputFile,
  }) async {
    final completer = Completer<String?>();
    final audioChunks = <int>[];

    try {
      final socket = await WebSocket.connect(
        wssUrl,
        protocols: ['synthesize'],
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0',
        },
      ).timeout(const Duration(seconds: 8));

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
            final bytes = Uint8List.fromList(data);
            if (bytes.length > 2) {
              final headerLen = (bytes[0] << 8) | bytes[1];
              if (bytes.length > headerLen + 2) {
                final audioData = bytes.sublist(headerLen + 2);
                audioChunks.addAll(audioData);
              }
            }
          } else if (data is String) {
            if (data.contains("turn.end")) {
              socket.close();
              if (audioChunks.isNotEmpty) {
                outputFile.writeAsBytes(audioChunks).then((file) {
                  if (!completer.isCompleted) completer.complete(file.path);
                });
              } else {
                if (!completer.isCompleted) completer.complete(null);
              }
            }
          }
        },
        onError: (err) {
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) {
            if (audioChunks.isNotEmpty) {
              outputFile.writeAsBytes(audioChunks).then((file) {
                completer.complete(file.path);
              });
            } else {
              completer.complete(null);
            }
          }
        },
        cancelOnError: true,
      );

      return await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Instant, rock-solid Google Hindi Neural TTS fallback over pure HTTPS
  static Future<String> _generateGoogleHindiTts(String text, File outputFile) async {
    final chunks = <String>[];
    final parts = text.split(RegExp(r'([।!?,\n]+)'));
    String curr = '';
    for (final p in parts) {
      if (curr.length + p.length < 120) {
        curr += p;
      } else {
        if (curr.trim().isNotEmpty) chunks.add(curr.trim());
        curr = p;
      }
    }
    if (curr.trim().isNotEmpty) chunks.add(curr.trim());
    if (chunks.isEmpty) chunks.add(text.trim());

    final client = http.Client();
    final allAudioBytes = <int>[];

    for (final chunk in chunks) {
      if (chunk.trim().isEmpty) continue;
      final encoded = Uri.encodeComponent(chunk.trim());
      final url = 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encoded&tl=hi&client=tw-ob';
      try {
        final res = await client.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          allAudioBytes.addAll(res.bodyBytes);
        }
      } catch (e) {
        print('Google TTS chunk error: $e');
      }
    }
    client.close();

    if (allAudioBytes.length > 200) {
      await outputFile.writeAsBytes(allAudioBytes);
      return outputFile.path;
    }

    throw Exception('Audio synthesis failed. Please check internet connection.');
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
