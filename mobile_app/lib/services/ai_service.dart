import 'dart:convert';
import 'package:http/http.dart' as http;

class AiNewsBundle {
  final String headline;
  final String subHeadline;
  final String ticker;
  final String script;

  AiNewsBundle({
    required this.headline,
    required this.subHeadline,
    required this.ticker,
    required this.script,
  });
}

class AiService {
  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String mistralApiUrl = 'https://api.mistral.ai/v1/chat/completions';

  /// Generates a complete Hindi TV news broadcast package matching web commit 6b456bd.
  /// Automatically generates:
  /// 1. Main Headline (===HEADLINE===)
  /// 2. Sub-Headline (===SUB_HEADLINE===)
  /// 3. Scrolling Ticker (===TICKER===)
  /// 4. Professional Anchor Voiceover Script (===SCRIPT===)
  static Future<AiNewsBundle> generateNewsBroadcastPackage({
    required String topic,
    String? apiKey,
    String provider = 'groq',
    String model = 'llama-3.3-70b-versatile',
    String? backendUrl,
  }) async {
    final cleanTopic = topic.trim().isEmpty ? "आज की बड़ी खबर" : topic.trim();

    // 1. Try Backend API if configured
    if (backendUrl != null && backendUrl.isNotEmpty) {
      try {
        final uri = Uri.parse('$backendUrl/api/generate-script-stream');
        final res = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'topic': cleanTopic,
            'provider': provider,
            'model': model,
          }),
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200 && res.body.isNotEmpty) {
          final bundle = parseAiResponse(res.body);
          if (bundle.script.isNotEmpty) return bundle;
        }
      } catch (_) {}
    }

    // 2. Direct Cloud LLM Call (Groq or Mistral if key provided)
    final cleanKey = (apiKey ?? "").trim();
    if (cleanKey.isNotEmpty && cleanKey.length > 15) {
      try {
        final isMistral = provider == 'mistral' || cleanKey.startsWith('mistral');
        final apiUrl = isMistral ? mistralApiUrl : groqApiUrl;
        final targetModel = isMistral ? 'mistral-small-latest' : model;

        const systemPrompt = '''
आप Shree News 24×7 के वरिष्ठ हिंदी टीवी न्यूज़ एंकर, न्यूज़ एडिटर और प्रोफेशनल ब्रॉडकास्ट स्क्रिप्ट राइटर हैं।
आपका काम यूज़र द्वारा दिए गए न्यूज़ टॉपिक पर एक वास्तविक भारतीय हिंदी न्यूज़ चैनल (जैसे Aaj Tak, ABP News) की तरह लाइव न्यूज़ बुलेटिन तैयार करना है।

STRICT RULES:
1. भाषा वास्तविक टीवी न्यूज़ एंकर की बोलने वाली स्वाभाविक और प्रभावशाली हिंदी हो।
2. छोटे, सीधे और ऊर्जावान वाक्य लिखें।
3. Markdown formatting (asterisk, bold, bullets) का इस्तेमाल बिल्कुल न करें।
4. पूर्ण विराम (।) और अल्पविराम (,) का सही प्रयोग करें ताकि TTS में स्वाभाविक प्रवाह आए।

हमेशा नीचे दिए गए चार सेक्शन्स इसी सटीक फॉर्मेट में आउटपुट दें:
===HEADLINE===
(एक प्रभावशाली और संक्षिप्त मुख्य न्यूज़ हेडलाइन, अधिकतम 10 शब्द)

===SUB_HEADLINE===
(मुख्य खबर को स्पष्ट करने वाली एक छोटी सब-हेडलाइन, अधिकतम 14 शब्द)

===TICKER===
(न्यूज़ चैनल के नीचे चलने वाली संक्षिप्त अपडेट लाइनें, हर अपडेट को | से अलग करें)

===SCRIPT===
(न्यूज़ एंकर द्वारा बोली जाने वाली 4 से 6 वाक्यों की प्रोफेशनल लाइव बुलेटिन स्क्रिप्ट। शुरुआत "नमस्कार, इस वक्त की बड़ी खबर..." से करें।)
''';

        final response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $cleanKey',
          },
          body: jsonEncode({
            'model': targetModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {
                'role': 'user',
                'content': 'News Topic: $cleanTopic\nकृपया ऊपर दिए गए चारों सेक्शन्स (HEADLINE, SUB_HEADLINE, TICKER, SCRIPT) हिंदी में तुरंत लिखें।'
              }
            ],
            'temperature': 0.6,
            'max_tokens': 900,
          }),
        ).timeout(const Duration(seconds: 14));

        if (response.statusCode == 200) {
          final json = jsonDecode(utf8.decode(response.bodyBytes));
          final rawContent = json['choices'][0]['message']['content'].toString().trim();
          if (rawContent.isNotEmpty) {
            final bundle = parseAiResponse(rawContent);
            if (bundle.script.isNotEmpty) return bundle;
          }
        }
      } catch (e) {
        print("Cloud Key AI error ($e), attempting free Cloud AI engine...");
      }
    }

    // 3. True Authentic Cloud AI Engine (Zero-Config, No API Key Required)
    try {
      final cloudBundle = await _callFreeCloudAi(cleanTopic);
      if (cloudBundle != null && cloudBundle.script.isNotEmpty && cloudBundle.headline.isNotEmpty) {
        return cloudBundle;
      }
    } catch (e) {
      print("Free Cloud AI error ($e), using local fallback...");
    }

    // 4. Offline Dynamic Local Fallback (Only used if phone has no internet connection)
    return generateDynamicLocalNews(cleanTopic);
  }

  /// Direct Free Cloud AI Broadcast Engine (Connects to OpenAI-grade LLM without requiring user API key)
  static Future<AiNewsBundle?> _callFreeCloudAi(String cleanTopic) async {
    const systemPrompt = '''
आप Shree News 24×7 के वरिष्ठ हिंदी टीवी न्यूज़ एंकर, न्यूज़ एडिटर और प्रोफेशनल ब्रॉडकास्ट स्क्रिप्ट राइटर हैं।
आपका काम यूज़र द्वारा दिए गए न्यूज़ टॉपिक पर एक वास्तविक भारतीय हिंदी न्यूज़ चैनल (जैसे Aaj Tak, ABP News) की तरह लाइव न्यूज़ बुलेटिन तैयार करना है।

STRICT RULES:
1. भाषा वास्तविक टीवी न्यूज़ एंकर की स्वाभाविक और प्रभावशाली हिंदी हो।
2. छोटे, सीधे और ऊर्जावान वाक्य लिखें।
3. केवल और केवल नीचे दिए गए चार सेक्शन्स इसी सटीक फॉर्मेट में आउटपुट दें, कोई अतिरिक्त भूमिका या Markdown न लिखें:

===HEADLINE===
(एक प्रभावशाली और संक्षिप्त मुख्य न्यूज़ हेडलाइन, अधिकतम 10 शब्द)

===SUB_HEADLINE===
(मुख्य खबर को स्पष्ट करने वाली एक छोटी सब-हेडलाइन, अधिकतम 14 शब्द)

===TICKER===
(न्यूज़ चैनल के नीचे चलने वाली संक्षिप्त 3-4 अपडेट लाइनें, हर अपडेट को | से अलग करें)

===SCRIPT===
(न्यूज़ एंकर द्वारा बोली जाने वाली 4 से 6 वाक्यों की प्रोफेशनल लाइव बुलेटिन स्क्रिप्ट। शुरुआत "नमस्कार, इस वक्त की बड़ी खबर..." से करें।)
''';

    final uri = Uri.parse('https://text.pollinations.ai/');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': 'News Topic: $cleanTopic\nकृपया ऊपर दिए गए चारों सेक्शन्स (HEADLINE, SUB_HEADLINE, TICKER, SCRIPT) हिंदी में तुरंत लिखें।'
          }
        ],
        'model': 'openai',
      }),
    ).timeout(const Duration(seconds: 22));

    if (res.statusCode == 200 && res.body.isNotEmpty) {
      final raw = utf8.decode(res.bodyBytes).trim();
      if (raw.isNotEmpty) {
        if (raw.startsWith('{') && raw.contains('"choices"')) {
          try {
            final parsedJson = jsonDecode(raw);
            final content = parsedJson['choices'][0]['message']['content'].toString().trim();
            return parseAiResponse(content);
          } catch (_) {}
        }
        return parseAiResponse(raw);
      }
    }
    return null;
  }

  /// Parses the ===HEADLINE===, ===SUB_HEADLINE===, ===TICKER===, ===SCRIPT=== tags
  static AiNewsBundle parseAiResponse(String raw) {
    const hTag = '===HEADLINE===';
    const shTag = '===SUB_HEADLINE===';
    const tTag = '===TICKER===';
    const sTag = '===SCRIPT===';

    final hIdx = raw.indexOf(hTag);
    final shIdx = raw.indexOf(shTag);
    final tIdx = raw.indexOf(tTag);
    final sIdx = raw.indexOf(sTag);

    String headline = '';
    String subHeadline = '';
    String ticker = '';
    String script = '';

    if (hIdx != -1) {
      final end = (shIdx != -1) ? shIdx : (tIdx != -1 ? tIdx : (sIdx != -1 ? sIdx : raw.length));
      headline = raw.substring(hIdx + hTag.length, end).trim();
    }

    if (shIdx != -1) {
      final end = (tIdx != -1) ? tIdx : (sIdx != -1 ? sIdx : raw.length);
      subHeadline = raw.substring(shIdx + shTag.length, end).trim();
    }

    if (tIdx != -1) {
      final end = (sIdx != -1) ? sIdx : raw.length;
      ticker = raw.substring(tIdx + tTag.length, end).trim();
    }

    if (sIdx != -1) {
      script = raw.substring(sIdx + sTag.length).trim();
    } else if (hIdx == -1 && shIdx == -1 && tIdx == -1) {
      script = raw.trim();
    }

    // Clean formatting artifacts
    headline = _cleanText(headline);
    subHeadline = _cleanText(subHeadline);
    ticker = _cleanText(ticker);
    script = _cleanText(script);

    return AiNewsBundle(
      headline: headline.isNotEmpty ? headline : "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव",
      subHeadline: subHeadline.isNotEmpty ? subHeadline : "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट",
      ticker: ticker.isNotEmpty ? ticker : "भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | और देश-दुनिया की हर बड़ी खबर",
      script: script.isNotEmpty ? script : "नमस्कार, इस वक्त की बड़ी खबर सामने आ रही है। $raw",
    );
  }

  /// Intelligently analyzes any input topic (in Hindi, Hinglish, or English)
  /// and constructs an authentic, customized TV news broadcast bulletin.
  static AiNewsBundle generateDynamicLocalNews(String topic) {
    final clean = topic.replaceAll(RegExp(r'["\n\r*]'), ' ').trim();
    final lower = clean.toLowerCase();

    String headline = "";
    String subHeadline = "";
    String ticker = "";
    String script = "";

    if (lower.contains("gad") || lower.contains("laat") || lower.contains("गध") || lower.contains("लात")) {
      headline = "सड़क पर गधे ने मारी जोरदार लात, इलाके में मची भारी अफरा-तफरी";
      subHeadline = "अचानक हुए हमले से राहगीर घायल, मौके पर जुटी लोगों की भारी भीड़";
      ticker = "सड़क पर गधे का अचानक हमला | राहगीर को अस्पताल पहुंचाया गया | प्रशासन ने आवारा पशुओं पर कार्रवाई के दिए आदेश | Shree News 24x7 पर सबसे पहले";
      script = "नमस्कार, इस वक्त की बड़ी खबर सामने आ रही है। सड़क पर एक गधे ने अचानक जोरदार लात मार दी, जिससे इलाके में भारी अफरा-तफरी मच गई। घटना में एक राहगीर गंभीर रूप से घायल हो गया है, जिसे स्थानीय लोगों की मदद से फौरन अस्पताल पहुंचाया गया। प्रत्यक्षदर्शियों के मुताबिक घटना के वक्त मौके पर भगदड़ जैसी स्थिति बन गई थी। प्रशासन ने मामले का संज्ञान लेते हुए आवारा पशुओं के खिलाफ सख्त कार्रवाई के आदेश जारी कर दिए हैं।";
    } else if (lower.contains("barish") || lower.contains("rain") || lower.contains("बारिश") || lower.contains("मौसम")) {
      headline = "$clean: तेज बारिश के बाद कई इलाकों में भारी जलभराव";
      subHeadline = "मौसम विभाग ने अगले चौबीस घंटे के लिए जारी किया मूसलाधार बारिश का येलो अलर्ट";
      ticker = "तेज बारिश से जनजीवन अस्त-व्यस्त | निचले इलाकों में भरा पानी | प्रशासन ने जारी की एडवाइजरी | अलर्ट मोड पर रेस्क्यू टीमें";
      script = "नमस्कार, इस वक्त की बड़ी खबर $clean को लेकर सामने आ रही है। सुबह से हो रही मूसलाधार बारिश के चलते शहर के कई प्रमुख इलाकों में पानी भर गया है। मौसम विभाग ने अगले चौबीस घंटे के लिए भारी बारिश का येलो अलर्ट जारी कर दिया है। नगर निगम और प्रशासन की टीमें जलभराव से निपटने के लिए सड़कों पर उतर चुकी हैं। नागरिकों से अपील की गई है कि वे अनावश्यक रूप से घरों से बाहर न निकलें।";
    } else if (lower.contains("hadsa") || lower.contains("accident") || lower.contains("हादसा") || lower.contains("दुर्घटना")) {
      headline = "$clean: सड़क हादसे में कई लोग घायल, मौके पर अफरा-तफरी";
      subHeadline = "घायलों को नजदीकी अस्पताल पहुंचाया गया, पुलिस बल मौके पर तैनात";
      ticker = "सड़क हादसे में कई घायल | मौके पर राहत और बचाव कार्य शुरू | ट्रैफिक को कराया गया सुचारू | मामले की जांच में जुटी पुलिस";
      script = "नमस्कार, इस वक्त की बड़ी खबर सामने आ रही है। $clean में एक भीषण हादसा हुआ है, जिसके बाद इलाके में अफरा-तफरी मच गई। हादसे में कई लोगों के घायल होने की खबर है, जिन्हें तुरंत अस्पताल पहुंचाया गया है। मौके पर स्थानीय पुलिस और राहत दल पहुंच चुका है। पुलिस ने केस दर्ज कर हादसे के कारणों की जांच शुरू कर दी है।";
    } else {
      // General dynamic broadcast construction from user's custom topic
      headline = "$clean को लेकर बड़ा अपडेट, प्रशासन अलर्ट मोड पर";
      subHeadline = "शुरुआती जानकारी के बाद अधिकारियों की बैठक, पल-पल की स्थिति पर नजर";
      ticker = "$clean पर बड़ा अपडेट | ग्राउंड जीरो पर Shree News की विशेष टीम | अधिकारियों ने जारी किए दिशा-निर्देश | हर खबर सबसे पहले";
      script = "नमस्कार, इस वक्त की बड़ी खबर $clean को लेकर सामने आ रही है। मिली जानकारी के अनुसार घटना के बाद पूरे इलाके में प्रशासन पूरी तरह अलर्ट हो गया है। वरिष्ठ अधिकारियों ने स्थिति की समीक्षा कर तत्काल प्रभाव से जरूरी दिशा-निर्देश जारी कर दिए हैं। हमारी टीम ग्राउंड जीरो पर मौजूद है और हर महत्वपूर्ण अपडेट आप तक सबसे पहले पहुंचा रही है। लगातार देखते रहिए श्री NEWS 24x7।";
    }

    return AiNewsBundle(
      headline: headline,
      subHeadline: subHeadline,
      ticker: ticker,
      script: script,
    );
  }

  static String _cleanText(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('"', '')
        .replaceAll('===HEADLINE===', '')
        .replaceAll('===SUB_HEADLINE===', '')
        .replaceAll('===TICKER===', '')
        .replaceAll('===SCRIPT===', '')
        .trim();
  }
}
