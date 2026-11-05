import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TtsService {
  static const String _backendUrl = 'https://shree-news-studio.onrender.com';

  /// Fetches audio MP3 from Edge-TTS microservice in ~1 second
  static Future<String?> generateVoice({
    required String text,
    required String voiceId,
    required double speed,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/preview-voice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'voice_id': voiceId,
          'speed': speed,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['audio_url'] != null) {
          final audioUrl = '$_backendUrl${data['audio_url']}';
          
          // Download MP3 to local cache on the phone
          final audioResp = await http.get(Uri.parse(audioUrl));
          if (audioResp.statusCode == 200) {
            final tempDir = await getTemporaryDirectory();
            final localFile = File('${tempDir.path}/anchor_voice_${DateTime.now().millisecondsSinceEpoch}.mp3');
            await localFile.writeAsBytes(audioResp.bodyBytes);
            return localFile.path;
          }
        }
      }
    } catch (e) {
      print('TTS Generation error: $e');
    }
    return null;
  }
}

