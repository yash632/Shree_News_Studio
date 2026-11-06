import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit_config.dart';
import '../models/news_config.dart';
import 'tts_service.dart';

class MobileFfmpegService {
  /// Extracts Flutter assets into local filesystem so FFmpeg C-engine can read them
  static Future<String> _extractAsset(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${tempDir.path}/$fileName');
    if (!await file.exists()) {
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return file.path;
  }

  /// Generates the transparent broadcast news graphic overlay (Pillow equivalent in Flutter)
  static Future<String> _renderOverlayPng({
    required NewsConfig config,
    required int width,
    required int height,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final isVertical = height > width;
    final scale = isVertical ? width / 1080.0 : width / 1920.0;

    // 1. Top Red/White Bar
    final topBarPaint = ui.Paint()..color = const ui.Color(0xF0FFFFFF);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, width.toDouble(), 75 * scale), topBarPaint);

    final topTabPaint = ui.Paint()..color = const ui.Color(0xFFDC2626);
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, 240 * scale, 75 * scale), topTabPaint);

    // Top Bar text
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: "आज की बड़ी खबर",
      style: TextStyle(color: Colors.white, fontSize: 26 * scale, fontWeight: FontWeight.bold, fontFamily: 'Hind'),
    );
    textPainter.layout();
    textPainter.paint(canvas, ui.Offset(20 * scale, 18 * scale));

    // 2. Master Lower Third
    final ltY = isVertical ? height - (380 * scale) : height - (330 * scale);

    // 3D Breaking News Badge
    final badgeWidth = 360 * scale;
    final badgeHeight = 140 * scale;
    final badgePaint = ui.Paint()..color = const ui.Color(0xFFB91C1C);
    canvas.drawRect(ui.Rect.fromLTWH(20 * scale, ltY, badgeWidth, badgeHeight), badgePaint);

    final badgeBottomPaint = ui.Paint()..color = const ui.Color(0xFFF59E0B);
    canvas.drawRect(ui.Rect.fromLTWH(20 * scale, ltY + (badgeHeight * 0.65), badgeWidth, badgeHeight * 0.35), badgeBottomPaint);

    textPainter.text = TextSpan(
      text: config.badgeText,
      style: TextStyle(color: Colors.white, fontSize: 32 * scale, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );
    textPainter.layout();
    textPainter.paint(canvas, ui.Offset(35 * scale, ltY + (16 * scale)));

    textPainter.text = TextSpan(
      text: "LIVE BROADCAST",
      style: TextStyle(color: const Color(0xFF0F172A), fontSize: 20 * scale, fontWeight: FontWeight.bold, fontFamily: 'Hind'),
    );
    textPainter.layout();
    textPainter.paint(canvas, ui.Offset(45 * scale, ltY + (70 * scale)));

    // Headline Red Strip
    final hlX = (20 * scale) + badgeWidth + (10 * scale);
    final hlW = width - hlX - (20 * scale);
    final hlH = 75 * scale;
    final hlPaint = ui.Paint()..color = const ui.Color(0xF5DC2626);
    canvas.drawRect(ui.Rect.fromLTWH(hlX, ltY, hlW, hlH), hlPaint);

    textPainter.text = TextSpan(
      text: config.headline,
      style: TextStyle(color: Colors.white, fontSize: 34 * scale, fontWeight: FontWeight.bold, fontFamily: 'Hind'),
    );
    textPainter.layout(maxWidth: hlW - (40 * scale));
    textPainter.paint(canvas, ui.Offset(hlX + (20 * scale), ltY + (14 * scale)));

    // Sub-Headline White Strip
    final subY = ltY + hlH;
    final subH = 55 * scale;
    final subPaint = ui.Paint()..color = const ui.Color(0xF5FFFFFF);
    canvas.drawRect(ui.Rect.fromLTWH(hlX, subY, hlW, subH), subPaint);

    textPainter.text = TextSpan(
      text: config.subHeadline,
      style: TextStyle(color: const Color(0xFF0F172A), fontSize: 24 * scale, fontWeight: FontWeight.w600, fontFamily: 'Hind'),
    );
    textPainter.layout(maxWidth: hlW - (40 * scale));
    textPainter.paint(canvas, ui.Offset(hlX + (20 * scale), subY + (12 * scale)));

    // Bottom Ticker Strip
    final tickerY = height - (75 * scale);
    final tickerPaint = ui.Paint()..color = const ui.Color(0xFA0F172A);
    canvas.drawRect(ui.Rect.fromLTWH(0, tickerY, width.toDouble(), 75 * scale), tickerPaint);

    final tagPaint = ui.Paint()..color = const ui.Color(0xFFDC2626);
    final tagW = 240 * scale;
    canvas.drawRect(ui.Rect.fromLTWH(0, tickerY, tagW, 75 * scale), tagPaint);

    textPainter.text = TextSpan(
      text: config.tickerTag,
      style: TextStyle(color: Colors.white, fontSize: 24 * scale, fontWeight: FontWeight.bold, fontFamily: 'Hind'),
    );
    textPainter.layout();
    textPainter.paint(canvas, ui.Offset(25 * scale, tickerY + (18 * scale)));

    // Export transparent PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    final tempDir = await getTemporaryDirectory();
    final overlayFile = File('${tempDir.path}/mobile_overlay_${DateTime.now().millisecondsSinceEpoch}.png');
    await overlayFile.writeAsBytes(byteData!.buffer.asUint8List());
    return overlayFile.path;
  }

  /// Runs full hardware-accelerated local FFmpeg render on mobile device
  static Future<String?> renderBroadcastVideo({
    required NewsConfig config,
    required Function(int percent, String status) onProgress,
  }) async {
    if (config.videoPath == null || !File(config.videoPath!).existsSync()) {
      onProgress(-1, "Video footage file missing.");
      return null;
    }

    onProgress(10, "Preparing mobile broadcast engine...");

    final isVertical = config.aspectRatio == "9:16";
    final targetW = isVertical ? 1080 : 1920;
    final targetH = isVertical ? 1920 : 1080;

    // Extract assets
    final bgPath = await _extractAsset('assets/backgrounds/Glossy Red News Waves.png');
    final fontPath = await _extractAsset('assets/fonts/Hind-Bold.ttf');
    final logoPath = config.customLogoPath ?? await _extractAsset('assets/logo.png');

    onProgress(25, "Compositing 1080p broadcast overlays...");
    final overlayPath = await _renderOverlayPng(config: config, width: targetW, height: targetH);

    // Audio path
    String audioPath = config.customAudioPath ?? '';
    if (config.audioMode == 'tts') {
      onProgress(35, "Generating anchor voiceover...");
      final voiceFile = await TtsService.generateVoice(
        text: config.ttsText,
        voiceId: config.ttsVoice,
        speed: config.ttsSpeed,
      );
      if (voiceFile == null) {
        onProgress(-1, "Voiceover generation failed. Check your internet connection.");
        return null;
      }
      audioPath = voiceFile;
    }

    onProgress(45, "Encoding broadcast news video locally...");

    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/shree_news_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // PiP frame coordinates
    final vidW = (targetW * 0.72).toInt();
    final vidH = (targetH * 0.58).toInt();
    final vidX = (targetW - vidW) ~/ 2;
    final vidY = (targetH * 0.16).toInt();

    // Ticker coordinates
    final tickerX = (260 * (targetW / 1920.0)).toInt();
    final tickerY = (targetH - (55 * (targetH / 1080.0))).toInt();

    // FFmpeg command string
    final filterComplex = [
      // 1. Background
      "[2:v]scale=$targetW:$targetH:force_original_aspect_ratio=increase,crop=$targetW:$targetH,format=rgba[vbg]",
      // 2. Video Footage Window
      "[0:v]scale=$vidW:$vidH:force_original_aspect_ratio=decrease,setsar=1[vpip]",
      "[vbg][vpip]overlay=x=$vidX:y=$vidY[vbase]",
      // 3. News Overlay Graphic Plate
      "[vbase][3:v]overlay=0:0[vframe]",
      // 4. Scrolling News Ticker
      "[vframe]drawtext=fontfile='$fontPath':text='${config.tickerText}':fontcolor=white:fontsize=28:x=w-mod(t*180\\,w+text_w):y=$tickerY[vout]",
      // 5. Audio mixing
      "[0:a]volume=${config.footageVolume}[a_vid];[1:a]volume=1.0[a_tts];[a_vid][a_tts]amix=inputs=2:duration=first:dropout_transition=2[aout]"
    ].join(";");

    final cmd = [
      "-y",
      "-i", config.videoPath!,
      "-i", audioPath,
      "-loop", "1", "-i", bgPath,
      "-i", overlayPath,
      "-filter_complex", filterComplex,
      "-map", "[vout]",
      "-map", "[aout]",
      "-c:v", "libx264",
      "-preset", "ultrafast",
      "-threads", "4",
      "-crf", "23",
      "-c:a", "aac",
      "-b:a", "192k",
      "-pix_fmt", "yuv420p",
      "-shortest",
      "-movflags", "+faststart",
      outputPath
    ].join(" ");

    // Execute with real-time statistics
    FFmpegKitConfig.enableStatisticsCallback((stats) {
      final timeMs = stats.getTime();
      if (timeMs > 0) {
        final sec = timeMs ~/ 1000;
        final p = (50 + (sec * 2)).clamp(50, 95);
        onProgress(p, "Rendering video locally: ${sec}s processed...");
      }
    });

    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      onProgress(100, "News video generated successfully!");
      return outputPath;
    } else {
      final logs = await session.getAllLogsAsString();
      print("FFmpeg failed: $logs");
      onProgress(-1, "Video rendering encountered an error on device.");
      return null;
    }
  }
}
