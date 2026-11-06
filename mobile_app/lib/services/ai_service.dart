import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static Future<String> generateNewsScript({
    required String topic,
    required String apiKey,
    String model = 'llama-3.3-70b-versatile',
  }) async {
    if (topic.trim().isEmpty) {
      throw Exception('News topic cannot be empty.');
    }

    if (apiKey.trim().isEmpty) {
      throw Exception('Groq API Key is required for AI Script generation.');
    }

    const systemPrompt = '''
आप Shree News 24×7 के वरिष्ठ हिंदी टीवी न्यूज़ एंकर, न्यूज़ एडिटर और प्रोफेशनल ब्रॉडकास्ट स्क्रिप्ट राइटर हैं।
आपका काम यूज़र द्वारा दिए गए किसी भी न्यूज़ टॉपिक पर एक वास्तविक भारतीय हिंदी न्यूज़ चैनल (जैसे Aaj Tak, ABP News) की तरह लाइव एंकर स्क्रिप्ट प्रस्तुत करना है।
नियम:
1. भाषा टीवी न्यूज़ एंकर की बोलने वाली शुद्ध और प्रभावशाली हिंदी हो।
2. वाक्य छोटे, दमदार और स्पष्ट हों।
3. एंकर की ऊर्जावान शुरुआत ("नमस्कार, आप देख रहे हैं श्री NEWS 24x7... और इस वक्त की बड़ी खबर...") से शुरू करें।
4. केवल पढ़ने योग्य स्क्रिप्ट लौटाएं (बिना किसी ब्रैकेट [ANCHOR ACTION] या कैमरा दिशा-निर्देशों के)।
''';

    final response = await http.post(
      Uri.parse(groqApiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': 'News Topic: $topic\nकृपया 30 से 45 सेकंड की दमदार हिंदी न्यूज़ एंकर स्क्रिप्ट लिखें।'}
        ],
        'temperature': 0.7,
        'max_tokens': 800,
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception('Groq API Error (${response.statusCode}): ${response.body}');
    }
  }
}
