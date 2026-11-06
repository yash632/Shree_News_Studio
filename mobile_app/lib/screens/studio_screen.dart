import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../models/broadcast_config.dart';
import '../services/ai_service.dart';
import '../services/tts_service.dart';
import '../services/video_engine_service.dart';

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
  final TextEditingController _tickerController = TextEditingController();
  final TextEditingController _scriptController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _outroController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();

  String? _selectedVideoPath;
  String? _selectedVideoName;
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
    _tickerController.text = _config.tickerText;
    _scriptController.text = "नमस्कार, आप देख रहे हैं श्री NEWS 24x7। भोपाल में आज सुबह से ही जोरदार बारिश का दौर जारी है। मौसम विभाग ने अगले 24 घंटे के लिए भारी बारिश का येलो अलर्ट जारी किया है।";
    _outroController.text = "अभी के लिए इतना ही, देश और दुनिया की तमाम बड़ी खबरों के लिए देखते रहिए श्री NEWS Twenty Four by Seven।";

    _initWebView();
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
          },
        ),
      )
      ..loadFlutterAsset('assets/web/index.html');
  }

  /// Sends updated text and configuration to the In-App Web View to update the live monitor
  void _syncConfigToWeb() {
    if (!_isWebViewReady) return;

    final jsCode = '''
      var hl = document.getElementById("hl");
      if (hl) hl.textContent = ${jsonEncode(_headlineController.text)};
      var sub = document.getElementById("subt");
      if (sub) sub.textContent = ${jsonEncode(_subHeadlineController.text)};
      var loc = document.getElementById("location");
      if (loc) loc.textContent = ${jsonEncode(_locationController.text.replaceAll('📍', '').trim())};
      var trk = document.getElementById("track");
      if (trk) {
        var t = ${jsonEncode(_tickerController.text)};
        trk.innerHTML = "<span>" + t + "</span><span>" + t + "</span>";
      }
      if (typeof fitAll === "function") fitAll();
      if (typeof fit === "function") fit();
    ''';
    _webViewController.runJavaScript(jsCode);
  }

  /// Picks background video from gallery/storage
  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedVideoPath = result.files.single.path;
        _selectedVideoName = result.files.single.name;
      });
    }
  }

  /// Generates authentic Hindi news script via Groq
  Future<void> _generateScript() async {
    if (_topicController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया न्यूज़ टॉपिक दर्ज करें।')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressStatus = "AI न्यूज़ एंकर स्क्रिप्ट लिख रहा है...";
    });

    try {
      final script = await AiService.generateNewsScript(
        topic: _topicController.text,
        apiKey: _apiKeyController.text.trim().isNotEmpty
            ? _apiKeyController.text.trim()
            : "gsk_free_key",
      );

      setState(() {
        _scriptController.text = script;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('स्क्रिप्ट सफलतापूर्वक तैयार हो गई!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI Script Error: $e')),
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
        const SnackBar(content: Text('कृपया बैकग्राउंड वीडियो फुटेज चुनें।')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _progressValue = 0.05;
      _progressStatus = "Taking 100% pixel-perfect snapshot of Web UI...";
      _finalVideoPath = null;
    });

    try {
      // 1. Capture exact Web UI overlay snapshot from WebView (with transparent frame center)
      await _webViewController.runJavaScript('''
        if (typeof window.prepareForOverlayExport === "function") {
          window.prepareForOverlayExport();
        } else {
          document.body.style.background = "transparent";
          var cv = document.getElementById("canvas");
          if (cv) cv.style.background = "transparent";
          var gl = document.querySelector(".glow");
          if (gl) gl.style.display = "none";
        }
      ''');
      await Future.delayed(const Duration(milliseconds: 150));

      final imageBytes = await _webViewController.takeScreenshot();

      // Restore monitor background
      await _webViewController.runJavaScript('''
        if (typeof window.restoreAfterOverlayExport === "function") {
          window.restoreAfterOverlayExport();
        } else {
          document.body.style.background = "#000";
          var cv = document.getElementById("canvas");
          if (cv) cv.style.background = "radial-gradient(ellipse at 50% 45%,#1b2a6b 0%,#0c1440 45%,#2a0a14 100%)";
          var gl = document.querySelector(".glow");
          if (gl) gl.style.display = "block";
        }
      ''');

      if (imageBytes == null || imageBytes.isEmpty) {
        throw Exception("Failed to capture Web UI monitor snapshot.");
      }

      final tempDir = await getTemporaryDirectory();
      final overlayFile = File('${tempDir.path}/web_overlay_${DateTime.now().millisecondsSinceEpoch}.png');
      await overlayFile.writeAsBytes(imageBytes);

      // 2. Synthesize Hindi News Anchor Speech locally via Edge-TTS
      setState(() {
        _progressValue = 0.20;
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
      _config.headlineText = _headlineController.text;
      _config.subHeadline = _subHeadlineController.text;
      _config.locationText = _locationController.text;
      _config.tickerText = _tickerController.text;

      final outputVideo = await VideoEngineService.renderVideo(
        videoPath: _selectedVideoPath!,
        audioPath: audioPath,
        overlayPath: overlayFile.path,
        config: _config,
        outroAudioPath: outroAudioPath,
        onProgress: (p, status) {
          setState(() {
            _progressValue = p;
            _progressStatus = status;
          });
        },
      );

      setState(() {
        _finalVideoPath = outputVideo;
        _isProcessing = false;
        _progressValue = 1.0;
        _progressStatus = "Professional broadcast video rendered successfully!";
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _progressStatus = "Error: $e";
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rendering Error: $e'), duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // 1. LIVE LAYOUT & OUTPUT MONITOR
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Live Layout & Output Monitor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        Chip(
                          label: Text('16:9 LANDSCAPE', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                          backgroundColor: Color(0xFF0F172A),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: WebViewWidget(controller: _webViewController),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. VIDEO FOOTAGE SELECTION
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
                    const Text('1. Background Video Footage *', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickVideo,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueAccent.withOpacity(0.5), style: BorderStyle.solid),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.video_library, color: Colors.blueAccent, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedVideoName ?? "Click to select background video footage from phone storage",
                                style: TextStyle(color: _selectedVideoName != null ? Colors.greenAccent : Colors.white70),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. BROADCAST METADATA & HEADLINES
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
                    const Text('2. News Broadcast Headlines', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _headlineController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Main News Headline (Devanagari)', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (_) => _syncConfigToWeb(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _subHeadlineController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Sub Headline / Details', labelStyle: TextStyle(color: Colors.white70)),
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
                    TextField(
                      controller: _tickerController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Bottom Scrolling News Ticker', labelStyle: TextStyle(color: Colors.white70)),
                      onChanged: (_) => _syncConfigToWeb(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 4. AUDIO & VOICEOVER ENGINE
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
                    const Text('3. Audio & Voiceover Engine (AI Anchor)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _scriptController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Anchor Voiceover Script', labelStyle: TextStyle(color: Colors.white70), border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
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
                            onChanged: (v) => setState(() => _ttsSpeed = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 5. TIMELINE & BROADCAST MODES
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
                    const Text('4. Broadcast Playback Flow & Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _config.audioMixMode,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: 'voiceover_only', child: Text('Mode 1: Voiceover Only (Footage Completely Muted)')),
                        DropdownMenuItem(value: 'voiceover_ambient', child: Text('Mode 2: Voiceover + Background Ambient Sound')),
                        DropdownMenuItem(value: 'intro_then_ground_outro', child: Text('Mode 3: 3-Stage TV Package (Anchor Intro → Ground → Outro)')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _config.audioMixMode = v);
                      },
                    ),
                    if (_config.audioMixMode == "intro_then_ground_outro") ...[
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Mute footage while anchor speaks (Intro & Outro)', style: TextStyle(color: Colors.white70)),
                        value: _config.muteDuringAnchor,
                        onChanged: (v) => setState(() => _config.muteDuringAnchor = v ?? true),
                      ),
                      CheckboxListTile(
                        title: const Text('Restart video from 0:00 when anchor finishes', style: TextStyle(color: Colors.white70)),
                        value: _config.restartFootage,
                        onChanged: (v) => setState(() => _config.restartFootage = v ?? false),
                      ),
                      CheckboxListTile(
                        title: const Text('Restart video from 0:00 for Outro / Sign-off', style: TextStyle(color: Colors.white70)),
                        value: _config.restartOutroFootage,
                        onChanged: (v) => setState(() => _config.restartOutroFootage = v ?? false),
                      ),
                      const SizedBox(height: 8),
                      Text('Ground Clip Duration: ${_config.groundClipDuration.round()}s', style: const TextStyle(color: Colors.white70)),
                      Slider(
                        value: _config.groundClipDuration,
                        min: 3,
                        max: 60,
                        onChanged: (v) => setState(() => _config.groundClipDuration = v),
                      ),
                      TextField(
                        controller: _outroController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Anchor Outro Script (Sign-off)', labelStyle: TextStyle(color: Colors.white70)),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // PROGRESS & STATUS
              if (_isProcessing || _progressStatus.isNotEmpty) ...[
                LinearProgressIndicator(value: _progressValue > 0 ? _progressValue : null, color: Colors.redAccent, backgroundColor: Colors.white24),
                const SizedBox(height: 8),
                Text(_progressStatus, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],

              // GENERATE BUTTON
              ElevatedButton(
                onPressed: _isProcessing ? null : _generateBroadcastVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.video_call, size: 26),
                    SizedBox(width: 10),
                    Text('⚡ GENERATE NEWS VIDEO (ON-DEVICE)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                  ],
                ),
              ),

              // DOWNLOAD / WATCH BUTTON
              if (_finalVideoPath != null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => OpenFile.open(_finalVideoPath!),
                  icon: const Icon(Icons.play_circle_fill, size: 26),
                  label: const Text('WATCH HD BROADCAST VIDEO', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

