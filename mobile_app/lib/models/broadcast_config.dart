class NewsVoice {
  final String id;
  final String name;
  final String lang;
  const NewsVoice({required this.id, required this.name, required this.lang});
}

const List<NewsVoice> kNewsVoices = [
  NewsVoice(id: 'hi-IN-MadhurNeural', name: '★ Madhur (Hindi Male - Classic News Anchor)', lang: 'Hindi'),
  NewsVoice(id: 'hi-IN-SwaraNeural', name: '★ Swara (Hindi Female - Classic News Anchor)', lang: 'Hindi'),
  NewsVoice(id: 'en-US-AndrewMultilingualNeural', name: '★ Andrew (Deep Male News Broadcaster)', lang: 'Hindi / English'),
  NewsVoice(id: 'en-US-AvaMultilingualNeural', name: '★ Ava (Prime-time Female Anchor)', lang: 'Hindi / English'),
  NewsVoice(id: 'google-hi', name: '★ Google Studio (Hindi Female - Smooth & Clear)', lang: 'Hindi'),
  NewsVoice(id: 'en-US-BrianMultilingualNeural', name: 'Brian (Authoritative TV Anchor)', lang: 'Hindi / English'),
  NewsVoice(id: 'en-US-EmmaMultilingualNeural', name: 'Emma (Crisp Studio Anchor)', lang: 'Hindi / English'),
  NewsVoice(id: 'en-IN-PrabhatNeural', name: 'Prabhat (Indian English Male Anchor)', lang: 'Indian English'),
  NewsVoice(id: 'en-IN-NeerjaNeural', name: 'Neerja (Indian English Female Anchor)', lang: 'Indian English'),
];

class BroadcastConfig {
  String headlineText;
  String subHeadline;
  String locationText;
  String tickerText;
  String tickerTag;
  String audioMixMode;
  bool restartFootage;
  bool restartOutroFootage;
  bool muteDuringAnchor;
  double groundClipDuration;
  double footageVolume;
  String aspectRatio;
  double frameScale; // 70.0 to 250.0 (100.0 default)
  bool enableTopBar;
  bool enableSidebar;
  bool enableLocation;
  bool enableDateTime;
  bool enableAnchor;
  bool enableTicker;
  List<String> sidebarItems;
  String outroText;
  String? customLogoPath;

  BroadcastConfig({
    this.headlineText = "श्री न्यूज़ 24x7 में आपका स्वागत है",
    this.subHeadline = "हम आपके लिए लाए हैं ताज़ा समाचार",
    this.locationText = "📍 भोपाल, मध्य प्रदेश",
    this.tickerText = "श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक",
    this.tickerTag = "ताजा खबर",
    this.audioMixMode = "voiceover_only",
    this.restartFootage = false,
    this.restartOutroFootage = false,
    this.muteDuringAnchor = true,
    this.groundClipDuration = 10.0,
    this.footageVolume = 0.20,
    this.aspectRatio = "16:9",
    this.frameScale = 100.0,
    this.enableTopBar = true,
    this.enableSidebar = false,
    this.enableLocation = true,
    this.enableDateTime = false,
    this.enableAnchor = false,
    this.enableTicker = true,
    List<String>? sidebarItems,
    this.outroText = "अभी के लिए इतना ही। देश और दुनिया की सभी बड़ी खबरों के लिए देखते रहिए श्री NEWS 24x7।",
    this.customLogoPath,
  }) : sidebarItems = sidebarItems ?? [
          "भोपाल से इस वक्त की बड़ी खबर",
          "प्रदेश में मौसम को लेकर नया अपडेट",
          "देश-दुनिया की खास खबरें",
          "बाजार में आज का हाल",
          "खेल जगत से बड़ी अपडेट"
        ];
}
