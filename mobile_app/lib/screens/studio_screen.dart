import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:video_player/video_player.dart';
import '../models/broadcast_config.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/video_engine_service.dart';
import '../services/overlay_renderer_service.dart';

class StudioScreen extends StatefulWidget {
  const StudioScreen({Key? key}) : super(key: key);

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final WebViewController _webViewController;
  bool _isWebViewReady = false;

  final BroadcastConfig _config = BroadcastConfig();

  // Form Controllers
  final TextEditingController _headlineController = TextEditingController();
  final TextEditingController _subHeadlineController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tickerTagController = TextEditingController();
  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _outroController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  // Media files & players
  String? _selectedVideoPath;
  String? _selectedVideoName;
  String? _selectedLogoPath;
  VideoPlayerController? _footagePlayerController;
  VideoPlayerController? _outputPlayerController;

  bool _isVertical = false;
  double _frameScale = 1.0; // 0.7 to 2.5
  String _selectedVoice = 'hi-IN-MadhurNeural';
  double _ttsSpeed = 1.0;

  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _progressStatus = "";
  String? _finalVideoPath;

  @override
  void initState() {
    super.initState();
    _headlineController.text = _config.headlineText;
    _subHeadlineController.text = _config.subHeadline;
    _locationController.text = _config.locationText;
    _tickerTagController.text = _config.tickerTag;
    _tickerController.text = _config.tickerText;
    _scriptController.text = "नमस्कार, आप देख रहे हैं श्री NEWS 24x7। भोपाल में आज सुबह से ही जोरदार बारिश का दौर जारी है। मौसम विभाग ने अगले 24 घंटे के लिए भारी बारिश का अलर्ट जारी किया है।";
    _outroController.text = "देश और दुनिया की तमाम बड़ी खबरों के लिए बने रहिए श्री NEWS 24x7 के साथ।";

    _initWebView();
  }

  @override
  void dispose() {
    _footagePlayerController?.dispose();
    _outputPlayerController?.dispose();
    super.dispose();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              _isWebViewReady = true;
            });
            _syncConfigToWeb();
            Future.delayed(const Duration(milliseconds: 300), _syncConfigToWeb);
            Future.delayed(const Duration(milliseconds: 800), _syncConfigToWeb);
          },
        ),
      )
      ..loadFlutterAsset('assets/web/index.html');
  }

  void _setAspectRatio(bool isVertical) {
    if (_isVertical == isVertical) return;
    setState(() {
      _isVertical = isVertical;
      _config.aspectRatio = isVertical ? "9:16" : "16:9";
    });
    _webViewController.loadFlutterAsset(
      isVertical ? 'assets/web/bhopal-news-bulletin.html' : 'assets/web/index.html',
    );
  }

  /// Sends updated text, toggles and scale to the in-app Web monitor
  void _syncConfigToWeb() {
    if (!_isWebViewReady) return;

    final jsCode = '''
      var hl = document.getElementById("hl") || document.getElementById("mainHeadline");
      if (hl) hl.textContent = ${jsonEncode(_headlineController.text)};
      var sub = document.getElementById("subt") || document.getElementById("subHeadline");
      if (sub) sub.textContent = ${jsonEncode(_subHeadlineController.text)};
      var loc = document.getElementById("location") || document.getElementById("locationText");
      if (loc) loc.textContent = ${jsonEncode(_locationController.text.replaceAll('📍', '').trim())};
      
      var lbl = document.getElementById("label");
      if (lbl) lbl.textContent = ${jsonEncode(_tickerTagController.text)};
      
      var trk = document.getElementById("track");
      if (trk) {
        var t = ${jsonEncode(_tickerController.text)};
        trk.innerHTML = "<span>" + t + "</span><span>" + t + "</span>";
      }

      // Toggles
      var hdr = document.getElementById("header");
      if (hdr) hdr.style.display = ${_config.enableTopBar} ? "block" : "none";
      var bnr = document.getElementById("banner");
      if (bnr) bnr.style.display = ${_config.enableTopBar} ? "block" : "none";
      var cards = document.querySelectorAll(".card");
      cards.forEach(function(c) { c.style.display = ${_config.enableTopBar} ? "flex" : "none"; });
      var lgo = document.getElementById("logo");
      if (lgo) lgo.style.display = ${_config.enableTopBar} ? "flex" : "none";

      var locBox = document.getElementById("loc");
      if (locBox) locBox.style.display = ${_config.enableLocation} ? "flex" : "none";

      var tm = document.getElementById("time");
      if (tm) tm.style.display = ${_config.enableDateTime && _config.enableTicker} ? "block" : "none";
      var dt = document.getElementById("date");
      if (dt) dt.style.display = ${_config.enableDateTime && _config.enableTicker} ? "block" : "none";

      var und = document.getElementById("under");
      if (und) und.style.display = ${_config.enableTicker} ? "block" : "none";
      var tkr = document.getElementById("ticker");
      if (tkr) tkr.style.display = ${_config.enableTicker} ? "block" : "none";
      if (lbl) lbl.style.display = ${_config.enableTicker} ? "block" : "none";

      var brk = document.getElementById("brk");
      if (brk) brk.style.top = ${_config.enableTicker} ? "765px" : "897px";

      if (typeof fitAll === "function") fitAll();
      if (typeof fit === "function") fit();
      if (typeof fitScreen === "function") fitScreen();
    ''';
    _webViewController.runJavaScript(jsCode);
  }

  /// Picks background video from phone storage and initializes live background monitor
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      setState(() {
        _selectedVideoPath = path;
        _selectedVideoName = result.files.single.name;
      });

      _footagePlayerController?.dispose();
      _footagePlayerController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (mounted) {
            _footagePlayerController?.setLooping(true);
            _footagePlayerController?.setVolume(0.0);
            _footagePlayerController?.play();
            setState(() {});
          }
        });
    }
  }

  /// Picks custom channel logo (PNG/JPG)
  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedLogoPath = result.files.single.path;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कस्टम चैनल लोगो सफलतापूर्वक लोड हुआ!')),
      );
    }
  }

  /// Generates authentic Hindi news script (Cloud Groq or Smart Offline Template)
  Future<void> _generateScript() async {
    setState(() {
      _isProcessing = true;
      _progressStatus = "AI न्यूज़ एंकर स्क्रिप्ट लिख रहा है...";
    });

    try {
      final script = await AiService.generateNewsScript(
        topic: _topicController.text,
        apiKey: _apiKeyController.text.trim(),
      );

      setState(() {
        _scriptController.text = script;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('एंकर स्क्रिप्ट तैयार हो गई!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Script info: $e')),
      );
    } finally {
      setState(() {
        _isProcessing = false;
        _progressStatus = "";
      });
    }
  }

  /// Generates the TV broadcast video locally using phone hardware
  Future<void> _generateBroadcastVideo() async {
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया पहले बैकग्राउंड वीडियो फुटेज चुनें।')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.08;
      _progressStatus = "Rendering broadcast graphics with authentic Hindi fonts...";
      _finalVideoPath = null;
    });

    try {
      _config.headlineText = _headlineController.text;
      _config.subHeadline = _subHeadlineController.text;
      _config.locationText = _locationController.text;
      _config.tickerTag = _tickerTagController.text;
      _config.tickerText = _tickerController.text;

      final targetW = _isVertical ? 720 : 1280;
      final targetH = _isVertical ? 1280 : 720;

      // 1. Generate high-fidelity broadcast overlay PNG (master web plate + HarfBuzz Hindi text)
      final overlayPath = await OverlayRendererService.generateOverlay(
        config: _config,
        targetWidth: targetW,
        targetHeight: targetH,
        customLogoPath: _selectedLogoPath,
      );

      // 2. Synthesize Hindi News Anchor Speech locally via Edge-TTS / Google Hindi TTS
      setState(() {
        _progressValue = 0.22;
        _progressStatus = "Synthesizing Hindi News Anchor voiceover...";
      });

      final audioPath = await TtsService.generateSpeech(
        text: _scriptController.text,
        voice: _selectedVoice,
        speed: _ttsSpeed,
      );

      String? outroAudioPath;
      if (_config.audioMixMode == "intro_then_ground_outro" && _outroController.text.trim().isNotEmpty) {
        setState(() {
          _progressValue = 0.35;
          _progressStatus = "Synthesizing Anchor Outro voiceover...";
        });
        outroAudioPath = await TtsService.generateSpeech(
          text: _outroController.text.trim(),
          voice: _selectedVoice,
          speed: _ttsSpeed,
        );
      }

      // 3. Render video using mobile local FFmpeg Engine
      final outputVideo = await VideoEngineService.renderVideo(
        videoPath: _selectedVideoPath!,
        audioPath: audioPath,
        overlayPath: overlayPath,
        config: _config,
        outroAudioPath: outroAudioPath,
        onProgress: (p, status) {
          setState(() {
            _progressValue = p;
            _progressStatus = status;
          });
        },
      );

      // Initialize in-app playback for the rendered video
      _outputPlayerController?.dispose();
      _outputPlayerController = VideoPlayerController.file(File(outputVideo))
        ..initialize().then((_) {
          if (mounted) {
            _outputPlayerController?.setLooping(true);
            _outputPlayerController?.play();
            setState(() {});
          }
        });

      setState(() {
        _finalVideoPath = outputVideo;
        _isProcessing = false;
        _progressValue = 1.0;
        _progressStatus = "HD Broadcast Video Ready!";
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _progressStatus = "Error: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rendering Error: $e'), duration: const Duration(seconds: 6)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitorRatio = _isVertical ? 9 / 16 : 16 / 9;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('SHREE NEWS STUDIO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _syncConfigToWeb,
            tooltip: 'Sync UI Monitor',
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. FORMAT SELECTOR & LIVE MONITOR
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Format selector (16:9 vs 9:16)
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _setAspectRatio(false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isVertical ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: !_isVertical ? Colors.redAccent : Colors.grey.shade800),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "16:9 Landscape (TV News)",
                                style: TextStyle(
                                  color: !_isVertical ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _setAspectRatio(true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isVertical ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _isVertical ? Colors.redAccent : Colors.grey.shade800),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "9:16 Reel / Short",
                                style: TextStyle(
                                  color: _isVertical ? Colors.white : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TV Screen Monitor Box (Stacked Video Player + Web UI overlay)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: Colors.black,
                          child: AspectRatio(
                            aspectRatio: monitorRatio,
                            child: Stack(
                              children: [
                                // Layer 1: Background Video Footage
                                if (_footagePlayerController != null && _footagePlayerController!.value.isInitialized)
                                  Positioned.fill(
                                    child: FittedBox(
                                      fit: _frameScale > 1.8 ? BoxFit.cover : BoxFit.contain,
                                      child: SizedBox(
                                        width: _footagePlayerController!.value.size.width,
                                        height: _footagePlayerController!.value.size.height,
                                        child: VideoPlayer(_footagePlayerController!),
                                      ),
                                    ),
                                  ),

                                // Layer 2: Live HTML5 Broadcast Graphics Template
                                Positioned.fill(
                                  child: WebViewWidget(controller: _webViewController),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. BROADCAST GRAPHICS TOGGLES (SCREENSHOT 2 FEATURE)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BROADCAST GRAPHICS TOGGLES',
                      style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Top Segment Bar (आज की बड़ी खबर)', style: TextStyle(color: Colors.white, fontSize: 12)),
                            value: _config.enableTopBar,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setState(() => _config.enableTopBar = val ?? true);
                              _syncConfigToWeb();
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Location Pin', style: TextStyle(color: Colors.white, fontSize: 12)),
                            value: _config.enableLocation,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setState(() => _config.enableLocation = val ?? true);
                              _syncConfigToWeb();
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Clock & Date Bar', style: TextStyle(color: Colors.white, fontSize: 12)),
                            value: _config.enableDateTime,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setState(() => _config.enableDateTime = val ?? true);
                              _syncConfigToWeb();
                            },
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bottom Ticker Bar', style: TextStyle(color: Colors.white, fontSize: 12)),
                            value: _config.enableTicker,
                            activeColor: Colors.redAccent,
                            onChanged: (val) {
                              setState(() => _config.enableTicker = val ?? true);
                              _syncConfigToWeb();
                            },
                          ),
                        ),
                      ],
                    ),

                    const Divider(color: Colors.white24, height: 24),

                    // Video Footage Screen Size Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Video Footage Screen Size', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber.shade900, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            "${(_frameScale * 100).toInt()}% ${_frameScale >= 2.0 ? '(Full Screen)' : _frameScale >= 1.5 ? '(Wide)' : _frameScale >= 1.0 ? '(Default)' : '(Compact)'}",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _frameScale,
                      min: 0.70,
                      max: 2.50,
                      divisions: 18,
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.white24,
                      onChanged: (v) {
                        setState(() => _frameScale = v);
                        _syncConfigToWeb();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. MEDIA UPLOADS (FOOTAGE & CUSTOM LOGO)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MEDIA UPLOADS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    // Background Video File Picker
                    InkWell(
                      onTap: _pickVideo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.video_library, color: Colors.blueAccent, size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedVideoName ?? "Click to pick background video footage from phone storage *",
                                style: TextStyle(color: _selectedVideoName != null ? Colors.greenAccent : Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Channel Logo Picker
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickLogo,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.image, color: Colors.amber, size: 24),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedLogoPath != null ? "Custom Logo Attached" : "Upload Custom Channel Logo (PNG/JPG)",
                                      style: TextStyle(color: _selectedLogoPath != null ? Colors.amberAccent : Colors.white70, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_selectedLogoPath != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () => setState(() => _selectedLogoPath = null),
                            tooltip: 'Remove Custom Logo',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. BROADCAST HEADLINES & DETAILS
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BROADCAST HEADLINES & TICKERS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _headlineController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Main News Headline (Red Bar) *', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (_) => _syncConfigToWeb(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _subHeadlineController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Sub-headline (White Bar)', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (_) => _syncConfigToWeb(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _locationController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Location Tag (e.g. 📍 भोपाल, मध्य प्रदेश)', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (_) => _syncConfigToWeb(),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _tickerTagController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Ticker Tag', labelStyle: TextStyle(color: Colors.white70)),
                            onChanged: (_) => _syncConfigToWeb(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _tickerController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Scrolling Ticker (Crawls Behind Tag)', labelStyle: TextStyle(color: Colors.white70)),
                            onChanged: (_) => _syncConfigToWeb(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. AUDIO & VOICEOVER ENGINE
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('AUDIO & VOICEOVER ENGINE (AI ANCHOR)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _topicController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'AI Topic (e.g. भोपाल में भारी बारिश)', labelStyle: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _generateScript,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Write Script'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _scriptController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Anchor Voiceover Script', labelStyle: TextStyle(color: Colors.white70)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Voice:', style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _selectedVoice,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(value: 'hi-IN-MadhurNeural', child: Text('★ Madhur (Hindi Male News Anchor)')),
                            DropdownMenuItem(value: 'hi-IN-SwaraNeural', child: Text('★ Swara (Hindi Female News Anchor)')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedVoice = v);
                          },
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Speed: ${_ttsSpeed.toStringAsFixed(2)}x', style: const TextStyle(color: Colors.white70)),
                        Expanded(
                          child: Slider(
                            value: _ttsSpeed,
                            min: 0.75,
                            max: 1.5,
                            divisions: 15,
                            activeColor: Colors.purpleAccent,
                            onChanged: (v) => setState(() => _ttsSpeed = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 6. GENERATION PROGRESS BAR
              if (_isProcessing) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: _progressValue > 0 ? _progressValue : null, color: Colors.redAccent, backgroundColor: Colors.white12),
                      const SizedBox(height: 10),
                      Text(_progressStatus, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 7. RENDERED VIDEO OUTPUT PLAYER
              if (_finalVideoPath != null && _outputPlayerController != null && _outputPlayerController!.value.isInitialized) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('RENDERED BROADCAST VIDEO', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                          Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: monitorRatio,
                          child: VideoPlayer(_outputPlayerController!),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_outputPlayerController!.value.isPlaying) {
                                  _outputPlayerController!.pause();
                                } else {
                                  _outputPlayerController!.play();
                                }
                                setState(() {});
                              },
                              icon: Icon(_outputPlayerController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                              label: Text(_outputPlayerController!.value.isPlaying ? "Pause" : "Play"),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF334155)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (_finalVideoPath != null) {
                                  OpenFile.open(_finalVideoPath!);
                                }
                              },
                              icon: const Icon(Icons.open_in_new),
                              label: const Text("Open Fullscreen"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 8. GENERATE NEWS VIDEO BUTTON
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _generateBroadcastVideo,
                icon: const Icon(Icons.bolt, size: 26),
                label: const Text('GENERATE NEWS VIDEO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
