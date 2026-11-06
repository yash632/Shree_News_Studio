import 'dart:io';
import 'package:edge_tts/edge_tts.dart';
import 'package:path_provider/path_provider.dart';

class TtsService {
  /// Synthesizes neural Hindi speech directly on the device using Edge TTS.
  /// No API key required.
  static Future<String> generateSpeech({
    required String text,
    String voice = 'hi-IN-MadhurNeural', // Madhur (Male) or Swara (Female)
    double speed = 1.0,
  }) async {
    if (text.trim().isEmpty) {
      throw Exception('TTS text cannot be empty.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFile = File('${tempDir.path}/tts_$timestamp.mp3');

    // Calculate percentage rate for Edge TTS (e.g. 1.1x -> +10%)
    String rateStr = '+0%';
    if (speed != 1.0) {
      final pct = ((speed - 1.0) * 100).round();
      rateStr = pct >= 0 ? '+$pct%' : '$pct%';
    }

    try {
      final communicate = Communicate(
        text: text.trim(),
        voice: voice,
        rate: rateStr,
        pitch: '+0Hz',
      );

      await communicate.save(outputFile.path);

      if (await outputFile.exists() && await outputFile.length() > 500) {
        return outputFile.path;
      } else {
        throw Exception('TTS output file is empty or missing.');
      }
    } catch (e) {
      throw Exception('Failed to generate Edge-TTS speech: $e');
    }
  }
}
