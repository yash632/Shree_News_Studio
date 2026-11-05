import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/news_config.dart';
import '../constants/theme.dart';
import 'ticker_crawler.dart';

class LiveMonitor extends StatefulWidget {
  final NewsConfig config;
  final VoidCallback onToggleRatio;
  final VoidCallback onAudioPreview;

  const LiveMonitor({
    super.key,
    required this.config,
    required this.onToggleRatio,
    required this.onAudioPreview,
  });

  @override
  State<LiveMonitor> createState() => _LiveMonitorState();
}

class _LiveMonitorState extends State<LiveMonitor> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(LiveMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.videoPath != widget.config.videoPath) {
      _initVideo();
    }
  }

  void _initVideo() {
    _videoController?.dispose();
    _videoController = null;

    final path = widget.config.videoPath;
    if (path != null && File(path).existsSync()) {
      _videoController = VideoPlayerController.file(File(path))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.setLooping(true);
            _videoController?.play();
          }
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVertical = widget.config.aspectRatio == "9:16";
    final monitorRatio = isVertical ? 9 / 16 : 16 / 9;

    return Container(
      decoration: BoxDecoration(
        color: StudioTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StudioTheme.cardBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Monitor Header: Title & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tv, color: StudioTheme.accentRed, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Live Layout & Output Monitor",
                    style: TextStyle(
                      color: StudioTheme.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onAudioPreview,
                    icon: const Icon(Icons.play_arrow, size: 14, color: StudioTheme.accentBlue),
                    label: const Text("Live Audio Preview", style: TextStyle(color: StudioTheme.accentBlue, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: Color(0xFF1E3A5F)),
                      backgroundColor: const Color(0xFF0F2338),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onToggleRatio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E2412),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: StudioTheme.accentGold.withOpacity(0.5)),
                      ),
                      child: Text(
                        isVertical ? "9:16 PORTRAIT" : "16:9 LANDSCAPE",
                        style: const TextStyle(
                          color: StudioTheme.accentGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main TV Screen Box
          Center(
            child: AspectRatio(
              aspectRatio: monitorRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Studio Waves Background
                      Image.asset(
                        'assets/backgrounds/Glossy Red News Waves.png',
                        fit: BoxFit.cover,
                      ),

                      // 2. Video Footage Window (PiP)
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: isVertical ? 0.88 : 0.72,
                          heightFactor: isVertical ? 0.52 : 0.62,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF0B1120),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.6),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _videoController != null && _videoController!.value.isInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _videoController!.value.size.width,
                                      height: _videoController!.value.size.height,
                                      child: VideoPlayer(_videoController!),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF1E293B),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.videocam_outlined,
                                            size: isVertical ? 32 : 44,
                                            color: Colors.white.withOpacity(0.4),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "No Video Selected",
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: isVertical ? 10 : 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),

                      // 3. Top Broadcast Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: isVertical ? 36 : 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: isVertical ? 10 : 12),
                                height: double.infinity,
                                color: StudioTheme.accentRed,
                                alignment: Alignment.center,
                                child: Text(
                                  "आज की बड़ी खबर",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVertical ? 11 : 12,
                                    fontFamily: 'Hind',
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: widget.config.customLogoPath != null &&
                                        File(widget.config.customLogoPath!).existsSync()
                                    ? Image.file(
                                        File(widget.config.customLogoPath!),
                                        height: isVertical ? 26 : 22,
                                      )
                                    : Image.asset(
                                        'assets/logo.png',
                                        height: isVertical ? 26 : 22,
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 4. Master Lower Third Graphics
                      Positioned(
                        bottom: isVertical ? 34 : 26,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // 3D Breaking News Chevron Badge
                                Container(
                                  width: isVertical ? 85 : 120,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB91C1C),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 6),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                        child: Text(
                                          widget.config.badgeText,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: isVertical ? 9 : 12,
                                            fontFamily: 'Hind',
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        color: StudioTheme.accentGold,
                                        child: Text(
                                          "LIVE BROADCAST",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w900,
                                            fontSize: isVertical ? 6 : 8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),

                                // Headline & Subheadline Double Plate
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Red Headline Strip
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isVertical ? 6 : 10,
                                          vertical: isVertical ? 3 : 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: StudioTheme.accentRed.withOpacity(0.95),
                                          borderRadius: const BorderRadius.only(
                                            topRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          widget.config.headline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: isVertical ? 10 : 13,
                                            fontFamily: 'Hind',
                                          ),
                                        ),
                                      ),
                                      // White Subheadline Strip
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isVertical ? 6 : 10,
                                          vertical: isVertical ? 2 : 4,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.only(
                                            bottomRight: Radius.circular(4),
                                          ),
                                        ),
                                        child: Text(
                                          widget.config.subHeadline,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w700,
                                            fontSize: isVertical ? 8 : 10,
                                            fontFamily: 'Hind',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 5. Bottom Scrolling Ticker
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: isVertical ? 26 : 22,
                          color: const Color(0xFF0F172A),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                height: double.infinity,
                                color: StudioTheme.accentRed,
                                alignment: Alignment.center,
                                child: Text(
                                  widget.config.tickerTag,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVertical ? 10 : 11,
                                    fontFamily: 'Hind',
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TickerCrawler(
                                  text: widget.config.tickerText,
                                  speed: 40.0,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isVertical ? 9 : 11,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Hind',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
