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
  bool enableTopBar;
  bool enableSidebar;
  bool enableLocation;
  bool enableDateTime;
  bool enableAnchor;
  bool enableTicker;
  List<String> sidebarItems;

  BroadcastConfig({
    this.headlineText = "भोपाल में आज तेज बारिश, कई इलाकों में जलभराव",
    this.subHeadline = "मौसम विभाग ने अगले 24 घंटे के लिए जारी किया अलर्ट",
    this.locationText = "📍 भोपाल, मध्य प्रदेश",
    this.tickerText = "भोपाल | इंदौर | ग्वालियर | जबलपुर | उज्जैन | सागर | रीवा | और देश-दुनिया की हर खबर",
    this.tickerTag = "ताजा खबर",
    this.audioMixMode = "voiceover_only",
    this.restartFootage = false,
    this.restartOutroFootage = false,
    this.muteDuringAnchor = true,
    this.groundClipDuration = 10.0,
    this.footageVolume = 0.20,
    this.aspectRatio = "16:9",
    this.enableTopBar = true,
    this.enableSidebar = true,
    this.enableLocation = true,
    this.enableDateTime = true,
    this.enableAnchor = false,
    this.enableTicker = true,
    List<String>? sidebarItems,
  }) : sidebarItems = sidebarItems ?? [
          "भोपाल से इस वक्त की बड़ी खबर",
          "प्रदेश में मौसम को लेकर नया अपडेट",
          "देश-दुनिया की खास खबरें",
          "बाजार में आज का हाल",
          "खेल जगत से बड़ी अपडेट"
        ];
}

