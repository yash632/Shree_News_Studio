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
import '../services/local_video_server.dart';

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

  final List<TextEditingController> _sidebarControllers = [];

  // Media files
  String? _selectedVideoPath;
  String? _selectedVideoName;
  String? _selectedLogoPath;
  String? _selectedLogoBase64;
  String? _selectedAudioPath;
  String? _selectedAudioName;

  String _audioMode = "tts"; // "tts" or "upload"
  String _selectedVoice = 'hi-IN-MadhurNeural';
  double _ttsSpeed = 1.0;

  bool _isProcessing = false;
  double _progressValue = 0.0;
  String _progressStatus = "";
  String? _finalVideoPath;
  VideoPlayerController? _finalVideoPlayerController;

  @override
  void initState() {
    super.initState();
    _headlineController.text = _config.headlineText;
    _subHeadlineController.text = _config.subHeadline;
    _locationController.text = _config.locationText;
    _tickerTagController.text = _config.tickerTag;
    _tickerController.text = _config.tickerText;
    _scriptController.text =
        "नमस्कार, आप देख रहे हैं श्री NEWS 24x7। भोपाल में आज सुबह से ही जोरदार बारिश का दौर जारी है। मौसम विभाग ने अगले 24 घंटे के लिए भारी बारिश का येलो अलर्ट जारी किया है।";
    _outroController.text = _config.outroText;

    for (int i = 0; i < 5; i++) {
      _sidebarControllers.add(
        TextEditingController(
          text: i < _config.sidebarItems.length ? _config.sidebarItems[i] : "",
        ),
      );
    }

    LocalVideoServer.ensureStarted();
    _initWebView();
  }

  @override
  void dispose() {
    for (final c in _sidebarControllers) {
      c.dispose();
    }
    _headlineController.dispose();
    _subHeadlineController.dispose();
    _locationController.dispose();
    _tickerTagController.dispose();
    _tickerController.dispose();
    _scriptController.dispose();
    _topicController.dispose();
    _outroController.dispose();
    _apiKeyController.dispose();
    _finalVideoPlayerController?.dispose();
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
      ..loadFlutterAsset(
        _config.aspectRatio == "9:16"
            ? 'assets/web/bhopal-news-bulletin.html'
            : 'assets/web/index.html',
      );
  }

  void _setAspectRatio(String ratio) {
    if (_config.aspectRatio == ratio) return;
    setState(() {
      _config.aspectRatio = ratio;
    });
    _webViewController.loadFlutterAsset(
      ratio == "9:16"
          ? 'assets/web/bhopal-news-bulletin.html'
          : 'assets/web/index.html',
    );
  }

  void _syncConfigToWeb() {
    if (!_isWebViewReady) return;

    final sidebarList = _sidebarControllers.map((c) => c.text).toList();
    _config.sidebarItems = sidebarList;
    _config.headlineText = _headlineController.text;
    _config.subHeadline = _subHeadlineController.text;
    _config.locationText = _locationController.text;
    _config.tickerTag = _tickerTagController.text;
    _config.tickerText = _tickerController.text;

    final data = {
      'headline': _config.headlineText,
      'subtitle': _config.subHeadline,
      'location': _config.locationText,
      'locationEnabled': _config.enableLocation,
      'topBarEnabled': _config.enableTopBar,
      'sidebarEnabled': _config.aspectRatio == "16:9" && _config.enableSidebar,
      'datetimeEnabled': _config.enableDateTime,
      'anchorEnabled': _config.aspectRatio == "16:9" && _config.enableAnchor,
      'tickerEnabled': _config.enableTicker,
      'tickerTag': _config.tickerTag,
      'tickerText': _config.tickerText,
      'sidebarItems': sidebarList,
      'frameScale': _config.frameScale,
      'videoSrc': LocalVideoServer.videoUrl,
      'logoSrc': _selectedLogoBase64,
    };

    final jsCall = 'if (window.setPreviewData) { window.setPreviewData(${jsonEncode(data)}); }';
    _webViewController.runJavaScript(jsCall);
  }

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
      LocalVideoServer.setVideoPath(path);
      _syncConfigToWeb();
    }
  }

  void _clearVideo() {
    setState(() {
      _selectedVideoPath = null;
      _selectedVideoName = null;
    });
    LocalVideoServer.setVideoPath(null);
    _syncConfigToWeb();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final bytes = await File(path).readAsBytes();
      final base64String = base64Encode(bytes);
      final mime = path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      setState(() {
        _selectedLogoPath = path;
        _selectedLogoBase64 = 'data:$mime;base64,$base64String';
        _config.customLogoPath = path;
      });
      _syncConfigToWeb();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कस्टम चैनल लोगो लोड हुआ!')),
      );
    }
  }

  void _resetLogo() {
    setState(() {
      _selectedLogoPath = null;
      _selectedLogoBase64 = null;
      _config.customLogoPath = null;
    });
    _syncConfigToWeb();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedAudioPath = result.files.single.path!;
        _selectedAudioName = result.files.single.name;
      });
    }
  }

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

  Future<void> _generateBroadcastVideo() async {
    if (_selectedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया Step 1 में बैकग्राउंड वीडियो फ़ाइल चुनें!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_audioMode == "upload" && _selectedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया Step 2 में ऑडियो फ़ाइल चुनें!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_audioMode == "tts" && _scriptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया न्यूज़ एंकर स्क्रिप्ट लिखें!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.05;
      _progressStatus = "Preparing TV newsroom pipeline...";
      _finalVideoPath = null;
    });

    try {
      String mainAudioPath;
      String? outroAudioPath;

      if (_audioMode == "tts") {
        setState(() {
          _progressValue = 0.15;
          _progressStatus = "Synthesizing AI anchor voiceover...";
        });

        mainAudioPath = await TtsService.generateSpeech(
          text: _scriptController.text.trim(),
          voice: _selectedVoice,
          speed: _ttsSpeed,
        );

        if (_config.audioMixMode == "intro_then_ground_outro" &&
            _outroController.text.trim().isNotEmpty) {
          setState(() {
            _progressValue = 0.25;
            _progressStatus = "Synthesizing anchor outro conclusion...";
          });
          outroAudioPath = await TtsService.generateSpeech(
            text: _outroController.text.trim(),
            voice: _selectedVoice,
            speed: _ttsSpeed,
          );
        }
      } else {
        mainAudioPath = _selectedAudioPath!;
      }

      setState(() {
        _progressValue = 0.35;
        _progressStatus = "Compositing broadcast graphics overlays...";
      });

      final isVertical = _config.aspectRatio == "9:16";
      final targetW = isVertical ? 720 : 1280;
      final targetH = isVertical ? 1280 : 720;

      final overlayPath = await OverlayRendererService.generateOverlay(
        config: _config,
        targetWidth: targetW,
        targetHeight: targetH,
        customLogoPath: _selectedLogoPath,
      );

      final outputPath = await VideoEngineService.renderVideo(
        videoPath: _selectedVideoPath!,
        audioPath: mainAudioPath,
        overlayPath: overlayPath,
        config: _config,
        outroAudioPath: outroAudioPath,
        onProgress: (p, status) {
          if (mounted) {
            setState(() {
              _progressValue = p;
              _progressStatus = status;
            });
          }
        },
      );

      setState(() {
        _finalVideoPath = outputPath;
        _progressValue = 1.0;
        _progressStatus = "Complete!";
      });

      _finalVideoPlayerController?.dispose();
      _finalVideoPlayerController = VideoPlayerController.file(File(outputPath))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 HD ब्रॉडकास्ट वीडियो सफलतापूर्वक तैयार हो गया!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Rendering Error', style: TextStyle(color: Colors.redAccent)),
          content: SingleChildScrollView(
            child: Text('$e', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = _config.aspectRatio == "9:16";
    final monitorRatio = isVertical ? (9 / 16) : (16 / 9);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 2,
        title: Row(
          children: const [
            Text(
              'SHREE NEWS ',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
            ),
            Text(
              'STUDIO',
              style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
              _syncConfigToWeb();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // LIVE LAYOUT & OUTPUT MONITOR
              // ==========================================
              _buildMonitorCard(monitorRatio, isVertical),

              const SizedBox(height: 16),

              // ==========================================
              // 1. VIDEO FOOTAGE & CHANNEL LOGO
              // ==========================================
              _buildStep1Card(),

              const SizedBox(height: 16),

              // ==========================================
              // 2. AUDIO & VOICEOVER ENGINE
              // ==========================================
              _buildStep2Card(),

              const SizedBox(height: 16),

              // ==========================================
              // 3. BROADCAST LAYOUT, HEADLINES & TOGGLES
              // ==========================================
              _buildStep3Card(isVertical),

              const SizedBox(height: 16),

              // ==========================================
              // 4. BROADCAST AUDIO MIXING & VIDEO TIMELINE
              // ==========================================
              _buildStep4Card(),

              const SizedBox(height: 20),

              // ==========================================
              // GENERATE / DOWNLOAD BUTTON
              // ==========================================
              _buildGenerateSection(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Monitor Card
  Widget _buildMonitorCard(double monitorRatio, bool isVertical) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Layout & Output Monitor',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isVertical ? Colors.amber.withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isVertical ? Colors.amber : Colors.redAccent,
                  ),
                ),
                child: Text(
                  isVertical ? '9:16 VERTICAL' : '16:9 LANDSCAPE',
                  style: TextStyle(
                    color: isVertical ? Colors.amber : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Live WebView Monitor (Exact 16:9 or 9:16 layout)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.black,
                constraints: BoxConstraints(
                  maxHeight: isVertical ? 420 : 220,
                ),
                child: AspectRatio(
                  aspectRatio: monitorRatio,
                  child: WebViewWidget(controller: _webViewController),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Step 1: Media Files Card
  Widget _buildStep1Card() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("1", "Video Footage & Channel Logo"),
          const SizedBox(height: 14),

          // Background Video Footage Dropzone
          const Text(
            "Background Video Footage *",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickVideo,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedVideoPath != null ? Colors.green : const Color(0xFF475569),
                  style: BorderStyle.solid,
                ),
              ),
              child: _selectedVideoPath == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.video_library_outlined, color: Colors.blueAccent, size: 28),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Click to pick video footage",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text("MP4, MOV, WEBM, MKV",
                                style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedVideoName ?? "video.mp4",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                          onPressed: _clearVideo,
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Channel Logo Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                "Channel Logo (Fixed at Top-Right)",
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                "Default: logo.png",
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              InkWell(
                onTap: _pickLogo,
                child: Container(
                  width: 80,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade700),
                  ),
                  child: _selectedLogoPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(File(_selectedLogoPath!), fit: BoxFit.contain),
                        )
                      : const Center(
                          child: Icon(Icons.add_photo_alternate, color: Colors.amber, size: 26),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedLogoPath != null ? "✓ Custom Logo Active" : "✓ Shree News default logo active",
                      style: TextStyle(
                        color: _selectedLogoPath != null ? Colors.green : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      "Click box to upload custom channel logo (PNG/JPG)",
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                    if (_selectedLogoPath != null)
                      TextButton(
                        onPressed: _resetLogo,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 20),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text("↺ Revert to Default Logo",
                            style: TextStyle(color: Colors.amber, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2: Audio Engine Card
  Widget _buildStep2Card() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("2", "Audio & Voiceover Engine"),
          const SizedBox(height: 14),

          // Tabs: AI Anchor vs Direct Upload
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _audioMode = "tts"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _audioMode == "tts" ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _audioMode == "tts" ? Colors.blueAccent : Colors.grey.shade800),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.mic, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "AI Anchor (TTS)",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _audioMode = "upload"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _audioMode == "upload" ? const Color(0xFF3B82F6) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _audioMode == "upload" ? Colors.blueAccent : Colors.grey.shade800),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.audio_file, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          "Direct Audio Upload",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (_audioMode == "tts") ...[
            // AI Script Writer Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        "AI Script Writer",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text("Qwen / Llama 3.3", style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _topicController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: "विषय लिखें (e.g. भोपाल में भारी बारिश)...",
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _generateScript,
                        icon: const Icon(Icons.auto_awesome, size: 16),
                        label: const Text("Write", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA855F7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // News Script Textarea
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "News Script / Content *",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  "${_scriptController.text.length} chars",
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _scriptController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 14),

            // Voice Selector (All 9 Voices)
            const Text(
              "Anchor Voice (9 Professional TV Broadcasters)",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedVoice,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: kNewsVoices.map((voice) {
                    return DropdownMenuItem<String>(
                      value: voice.id,
                      child: Text(voice.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedVoice = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Voice Speed Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Voice Speed:", style: TextStyle(color: Colors.white, fontSize: 13)),
                Text("${_ttsSpeed.toStringAsFixed(2)}x",
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Slider(
              value: _ttsSpeed,
              min: 0.8,
              max: 2.0,
              divisions: 12,
              activeColor: Colors.redAccent,
              onChanged: (val) => setState(() => _ttsSpeed = val),
            ),
          ] else ...[
            // Direct Audio Upload
            InkWell(
              onTap: _pickAudio,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedAudioPath != null ? Colors.green : const Color(0xFF475569),
                  ),
                ),
                child: _selectedAudioPath == null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.upload_file, color: Colors.blueAccent, size: 26),
                          SizedBox(width: 8),
                          Text("Click to pick MP3, WAV or AAC audio",
                              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_selectedAudioName ?? "audio.mp3",
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Step 3: Broadcast Layout, Headlines & Toggles
  Widget _buildStep3Card(bool isVertical) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("3", "Broadcast Layout, Headlines & Toggles"),
          const SizedBox(height: 14),

          // Video Format Selector
          const Text("Video Format", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _setAspectRatio("16:9"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !isVertical ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: !isVertical ? Colors.redAccent : Colors.grey.shade800),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "16:9 Landscape (TV News)",
                      style: TextStyle(
                        color: !isVertical ? Colors.white : Colors.white60,
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
                  onTap: () => _setAspectRatio("9:16"),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isVertical ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isVertical ? Colors.redAccent : Colors.grey.shade800),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "9:16 Reel / Short",
                      style: TextStyle(
                        color: isVertical ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Broadcast Graphics Toggles
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "BROADCAST GRAPHICS TOGGLES",
                  style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                ),
                const SizedBox(height: 10),

                // Toggles Grid
                if (!isVertical) ...[
                  // 16:9 Landscape Mode: 6 Toggles in 2 Rows
                  Row(
                    children: [
                      Expanded(
                        child: _buildCheckbox(
                          label: "Top Segment Bar (आज की बड़ी खबर)",
                          value: _config.enableTopBar,
                          onChanged: (v) {
                            setState(() => _config.enableTopBar = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Left Sidebar (मुख्य खबरें 01-05)",
                          value: _config.enableSidebar,
                          onChanged: (v) {
                            setState(() => _config.enableSidebar = v ?? false);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Location Pin",
                          value: _config.enableLocation,
                          onChanged: (v) {
                            setState(() => _config.enableLocation = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCheckbox(
                          label: "Clock & Date Bar (10:25 AM | 28 Oct)",
                          value: _config.enableDateTime,
                          onChanged: (v) {
                            setState(() => _config.enableDateTime = v ?? false);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Studio Anchor Window (PiP)",
                          value: _config.enableAnchor,
                          onChanged: (v) {
                            setState(() => _config.enableAnchor = v ?? false);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Bottom Ticker Bar (ताजा खबर और टिकर पट्टी)",
                          value: _config.enableTicker,
                          onChanged: (v) {
                            setState(() => _config.enableTicker = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // 9:16 Portrait Mode: 4 Toggles (Sidebar & Anchor are hidden in 9:16!)
                  Row(
                    children: [
                      Expanded(
                        child: _buildCheckbox(
                          label: "Top Segment Bar (आज की बड़ी खबर)",
                          value: _config.enableTopBar,
                          onChanged: (v) {
                            setState(() => _config.enableTopBar = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Location Pin",
                          value: _config.enableLocation,
                          onChanged: (v) {
                            setState(() => _config.enableLocation = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                      Expanded(
                        child: _buildCheckbox(
                          label: "Clock & Date Bar",
                          value: _config.enableDateTime,
                          onChanged: (v) {
                            setState(() => _config.enableDateTime = v ?? false);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCheckbox(
                          label: "Bottom Ticker Bar (ताजा खबर और टिकर पट्टी)",
                          value: _config.enableTicker,
                          onChanged: (v) {
                            setState(() => _config.enableTicker = v ?? true);
                            _syncConfigToWeb();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Video Footage Screen Size Slider (70% - 250%)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("📺 Video Footage Screen Size",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "${_config.frameScale.toInt()}% ${_config.frameScale == 100 ? '(Default)' : (_config.frameScale >= 250 ? '(Full Screen)' : (_config.frameScale >= 180 ? '(Wide)' : '(Compact)'))}",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          Slider(
            value: _config.frameScale,
            min: 70,
            max: 250,
            divisions: 36,
            activeColor: Colors.redAccent,
            onChanged: (val) {
              setState(() => _config.frameScale = val);
              _syncConfigToWeb();
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("70% (Compact)", style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text("100% (Default)", style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text("180% (Wide)", style: TextStyle(color: Colors.white38, fontSize: 10)),
              Text("250% (Full Screen)", style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),

          const SizedBox(height: 14),

          // Location Tag Input
          if (_config.enableLocation) ...[
            const Text("Location Tag (e.g. 📍 भोपाल, मध्य प्रदेश)",
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _locationController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (_) => _syncConfigToWeb(),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Left Sidebar Headlines (16:9 only)
          if (!isVertical && _config.enableSidebar) ...[
            const Text("Left Sidebar Headlines (01 to 05)",
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...List.generate(5, (idx) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: TextField(
                  controller: _sidebarControllers[idx],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  onChanged: (_) => _syncConfigToWeb(),
                  decoration: InputDecoration(
                    prefixText: "0${idx + 1}  ",
                    prefixStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          // Main News Headline (Red Bar)
          const Text("Main News Headline (Red Bar) *",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _headlineController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (_) => _syncConfigToWeb(),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 14),

          // Sub-headline (White Bar)
          const Text("Sub-headline (White Bar)",
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _subHeadlineController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            onChanged: (_) => _syncConfigToWeb(),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F172A),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
            ),
          ),

          const SizedBox(height: 14),

          // Ticker Tag & Scrolling Ticker
          if (_config.enableTicker) ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Ticker Tag",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tickerTagController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => _syncConfigToWeb(),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Scrolling Ticker (Crawls Behind Tag)",
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _tickerController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        onChanged: (_) => _syncConfigToWeb(),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Step 4: Broadcast Audio Mixing & Video Timeline (TV Newsroom) (Screenshot 4)
  Widget _buildStep4Card() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Text("🎧 ", style: TextStyle(fontSize: 16)),
              Expanded(
                child: Text(
                  "Broadcast Audio Mixing & Video Timeline (TV Newsroom)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          const Text(
            "Broadcast Audio & Playback Flow",
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _config.audioMixMode,
                isExpanded: true,
                dropdownColor: const Color(0xFF0F172A),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: const [
                  DropdownMenuItem(
                    value: "voiceover_ambient",
                    child: Text("Mode 1: Voiceover + Ambient Footage Audio (TV Ducking ~20%)"),
                  ),
                  DropdownMenuItem(
                    value: "intro_then_ground",
                    child: Text("Mode 2: Anchor Intro ➔ Ground Video with 100% Natural Audio"),
                  ),
                  DropdownMenuItem(
                    value: "intro_then_ground_outro",
                    child: Text("Mode 3: 3-Stage TV Package (Anchor Intro ➔ Ground Clip ➔ Anchor Outro)"),
                  ),
                  DropdownMenuItem(
                    value: "voiceover_only",
                    child: Text("Mode 4: Voiceover Only (Mute Footage Sound)"),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _config.audioMixMode = val);
                },
              ),
            ),
          ),

          // Sub-options for Mode 1
          if (_config.audioMixMode == "voiceover_ambient") ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Footage Background Sound Level:", style: TextStyle(color: Colors.white, fontSize: 13)),
                Text("${(_config.footageVolume * 100).toInt()}%",
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Slider(
              value: _config.footageVolume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              activeColor: Colors.redAccent,
              onChanged: (val) => setState(() => _config.footageVolume = val),
            ),
          ],

          // Sub-options for Mode 2 & Mode 3
          if (_config.audioMixMode == "intro_then_ground" ||
              _config.audioMixMode == "intro_then_ground_outro") ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155), style: BorderStyle.solid),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Mute Footage Audio while Anchor is speaking",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      "एंकर के बोलते समय वीडियो की आवाज म्यूट रहेगी, ग्राउंड वीडियो में 100% ओरिजिनल आवाज चलेगी।",
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: _config.muteDuringAnchor,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => setState(() => _config.muteDuringAnchor = val ?? true),
                  ),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Ground Video Duration:", style: TextStyle(color: Colors.white, fontSize: 12)),
                      Text("${_config.groundClipDuration.toInt()} sec",
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: _config.groundClipDuration,
                    min: 3,
                    max: 120,
                    divisions: 117,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => setState(() => _config.groundClipDuration = val),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Restart Video from 0:00 when Anchor finishes",
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    value: _config.restartFootage,
                    activeColor: Colors.redAccent,
                    onChanged: (val) => setState(() => _config.restartFootage = val ?? false),
                  ),

                  // Mode 3 Outro Options
                  if (_config.audioMixMode == "intro_then_ground_outro") ...[
                    const Divider(color: Colors.white12),
                    const Text("Anchor Outro Script (Sign-off / Conclusion) *",
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _outroController,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.all(10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Restart Video from 0:00 for Outro / Sign-off",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      value: _config.restartOutroFootage,
                      activeColor: Colors.redAccent,
                      onChanged: (val) => setState(() => _config.restartOutroFootage = val ?? false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Generate & Download Section
  Widget _buildGenerateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isProcessing) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_progressStatus,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text("${(_progressValue * 100).toInt()}%",
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _progressValue,
                  backgroundColor: const Color(0xFF0F172A),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // GENERATE BUTTON
        InkWell(
          onTap: _isProcessing ? null : _generateBroadcastVideo,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE50914), Color(0xFFB81D24)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.bolt, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  "GENERATE NEWS VIDEO",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // DOWNLOAD / SAVE BUTTON (When Generated)
        if (_finalVideoPath != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.greenAccent),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 26),
                    SizedBox(width: 8),
                    Text(
                      "BROADCAST VIDEO READY!",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () {
                    OpenFile.open(_finalVideoPath!);
                  },
                  icon: const Icon(Icons.download_rounded, size: 22),
                  label: const Text(
                    "DOWNLOAD / OPEN BROADCAST VIDEO",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepHeader(String stepNum, String title) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(13),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
      value: value,
      activeColor: Colors.redAccent,
      onChanged: onChanged,
    );
  }
}
