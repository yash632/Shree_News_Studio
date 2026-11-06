import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  /// Generates a professional Hindi TV news anchor script.
  /// Uses Groq cloud AI if valid API key is present; otherwise instantly generates
  /// a high-energy authentic TV broadcast anchor script offline so it never throws an error.
  static Future<String> generateNewsScript({
    required String topic,
    String? apiKey,
    String model = 'llama-3.3-70b-versatile',
  }) async {
    final cleanTopic = topic.trim().isEmpty ? "आज की बड़ी खबर" : topic.trim();

    // 1. If valid Groq API key is supplied, attempt cloud generation
    if (apiKey != null && apiKey.trim().startsWith('gsk_') && apiKey.trim().length > 20) {
      try {
        const systemPrompt = '''
आप Shree News 24×7 के वरिष्ठ हिंदी टीवी न्यूज़ एंकर, न्यूज़ एडिटर और प्रोफेशनल ब्रॉडकास्ट स्क्रिप्ट राइटर हैं।
आपका काम यूज़र द्वारा दिए गए न्यूज़ टॉपिक पर एक वास्तविक भारतीय हिंदी न्यूज़ चैनल (जैसे Aaj Tak, ABP News) की तरह लाइव एंकर स्क्रिप्ट प्रस्तुत करना है।
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
              {
                'role': 'user',
                'content': 'News Topic: $cleanTopic\nकृपया 30 से 45 सेकंड की दमदार हिंदी न्यूज़ एंकर स्क्रिप्ट लिखें।'
              }
            ],
            'temperature': 0.7,
            'max_tokens': 800,
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          final content = json['choices'][0]['message']['content'].toString().trim();
          if (content.isNotEmpty) {
            return content;
          }
        }
      } catch (e) {
        print('Groq cloud call failed ($e), generating offline script...');
      }
    }

    // 2. Instant Smart Script Generation (Offline / Zero-Config fallback)
    return generateSmartScript(cleanTopic);
  }

  /// High-energy authentic Hindi TV news broadcast anchor script template
  static String generateSmartScript(String topic) {
    final clean = topic.replaceAll('"', '').trim();
    return "नमस्कार, आप देख रहे हैं श्री NEWS 24x7 और मैं हूँ आपका न्यूज़ एंकर। इस वक्त की सबसे बड़ी खबर $clean को लेकर सामने आ रही है। सूत्रों से मिली जानकारी के मुताबिक हालात पर प्रशासन पूरी तरह से नजर बनाए हुए है। अधिकारियों ने स्थिति की समीक्षा कर जरूरी दिशा-निर्देश जारी कर दिए हैं। हमारी विशेष टीम ग्राउंड जीरो पर मौजूद है और पल-पल की ताजा जानकारी आप तक पहुंचा रही है। देश और दुनिया की तमाम बड़ी और सटीक खबरों के लिए लगातार देखते रहिए श्री NEWS 24x7।";
  }
}
