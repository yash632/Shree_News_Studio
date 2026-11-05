import 'dart:convert';
import 'package:http/http.dart' as http;

class AiScriptService {
  static const String _backendUrl = 'https://shree-news-studio.onrender.com';

  /// Generates a fast Hindi news script using LangChain / Groq API in ~1 second
  static Future<String?> generateScript(String topic) async {
    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/generate-script-stream'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'topic': topic,
          'provider': 'groq',
          'model': 'qwen-qwq-32b',
        }),
      );

      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (e) {
      print('AI Script generation error: $e');
    }
    return null;
  }
}
