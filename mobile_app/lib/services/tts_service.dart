import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TtsService {
  // Official Microsoft Edge Neural TTS endpoint key & trusted token
  static const String endpointKey = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
  static const String trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4";
  static const String wssUrl =
      "wss://api.msedgeservices.com/tts/cognitiveservices/websocket/v1?Ocp-Apim-Subscription-Key=$endpointKey";

  /// Generates the Microsoft DRM Sec-MS-GEC token required by Edge TTS
  static String _generateSecMsGec() {
    const winEpoch = 11644473600;
    final nowSeconds = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    var ticks = nowSeconds + winEpoch;
    ticks -= (ticks % 300); // 5-minute window
    final strToHash = "${ticks * 10000000}$trustedClientToken";
    return sha256.convert(ascii.encode(strToHash)).toString().toUpperCase();
  }

  static String _generateConnectionId() {
    final rand = Random();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _getTimestamp() {
    final now = DateTime.now().toUtc();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T"
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}Z";
  }

  /// Generates natural Hindi speech audio.
  /// Uses authentic Microsoft Edge Neural TTS (Madhur / Swara / Andrew);
  /// falls back to Google TTS only in case of complete offline outage.
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
      } catch (_) {}
    }

    // 2. Microsoft Edge Neural WebSocket with DRM Sec-MS-GEC Authentication
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
      print('Edge TTS WebSocket attempt failed ($e), using Google Hindi TTS...');
    }

    // 3. Fallback: Google Hindi TTS
    return await _generateGoogleHindiTts(text, outputFile);
  }

  /// Synthesizes neural voice via Edge TTS WebSocket using Sec-MS-GEC DRM authentication
  static Future<String?> _generateEdgeTts({
    required String text,
    required String voice,
    required String rateStr,
    required File outputFile,
  }) async {
    final completer = Completer<String?>();
    final audioChunks = <int>[];

    try {
      final connId = _generateConnectionId();
      final secMsGec = _generateSecMsGec();
      final connectUrl =
          "$wssUrl&ConnectionId=$connId&Sec-MS-GEC=$secMsGec&Sec-MS-GEC-Version=1-140.0.3485.14";

      final socket = await WebSocket.connect(
        connectUrl,
        protocols: ['synthesize'],
        headers: {
          'Pragma': 'no-cache',
          'Cache-Control': 'no-cache',
          'Origin': 'chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36 Edg/140.0.0.0',
        },
      ).timeout(const Duration(seconds: 10));

      final reqId = _generateConnectionId();
      final timeStr = _getTimestamp();

      // Step A: Send Speech Config
      final configMsg =
          "X-Timestamp:$timeStr\r\n"
          "Content-Type:application/json; charset=utf-8\r\n"
          "Path:speech.config\r\n\r\n"
          '{"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":"false","wordBoundaryEnabled":"false"},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}';
      socket.add(configMsg);

      // Step B: Send SSML
      final ssml =
          "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='hi-IN'>"
          "<voice name='$voice'><prosody rate='$rateStr'>${_escapeXml(text)}</prosody></voice></speak>";

      final ssmlMsg =
          "X-RequestId:$reqId\r\n"
          "X-Timestamp:$timeStr\r\n"
          "Content-Type:application/ssml+xml\r\n"
          "Path:ssml\r\n\r\n$ssml";
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
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
    } catch (e) {
      print("Edge TTS direct WebSocket error: $e");
      return null;
    }
  }

  /// Instant Google Hindi TTS fallback
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
      } catch (_) {}
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
