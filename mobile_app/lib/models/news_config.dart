class NewsConfig {
  String? videoPath;
  String? customLogoPath;
  String? customAudioPath;

  // Texts
  String badgeText;
  String headline;
  String subHeadline;
  String tickerTag;
  String tickerText;
  String locationText;
  String timeText;
  String dateText;
  String dayText;

  // Format
  String aspectRatio; // '16:9' or '9:16'
  double frameScale; // 70 to 250 (default 100)

  // Audio & Voice
  String audioMode; // 'tts' or 'upload'
  String ttsText;
  String ttsVoice; // 'hi-IN-MadhurNeural' or 'hi-IN-SwaraNeural'
  double ttsSpeed; // 0.8 to 1.5
  String audioMixMode; // 'voiceover_ambient' or 'intro_then_ground'
  double footageVolume; // 0.0 to 1.0 (default 0.2)
  double groundDuration; // seconds
  bool restartFootage;

  NewsConfig({
    this.videoPath,
    this.customLogoPath,
    this.customAudioPath,
    this.badgeText = "BREAKING NEWS",
    this.headline = "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव",
    this.subHeadline = "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट",
    this.tickerTag = "ताजा खबर",
    this.tickerText = "भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | सागर | रीवा | और देश-दुनिया की हर खबर",
    this.locationText = "📍 भोपाल, मध्य प्रदेश",
    this.timeText = "10:25 AM",
    this.dateText = "28 Oct 2026",
    this.dayText = "मंगलवार",
    this.aspectRatio = "16:9",
    this.frameScale = 100,
    this.audioMode = "tts",
    this.ttsText = "भोपाल में आज मूसलाधार बारिश दर्ज की गई है। शहर के निचले इलाकों में जलभराव की स्थिति बन गई है।",
    this.ttsVoice = "hi-IN-MadhurNeural",
    this.ttsSpeed = 1.0,
    this.audioMixMode = "voiceover_ambient",
    this.footageVolume = 0.20,
    this.groundDuration = 10.0,
    this.restartFootage = false,
  });
}
