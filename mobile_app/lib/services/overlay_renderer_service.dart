import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/broadcast_config.dart';

class FrameLayout {
  final double x;
  final double y;
  final double w;
  final double h;
  final double anchorX;
  FrameLayout({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.anchorX,
  });
}

class OverlayRendererService {
  /// Calculates footage frame & anchor coordinates matching web app.js 1:1
  static FrameLayout calculateFrameLayout(BroadcastConfig config) {
    final scaleVal = config.frameScale;
    final scale = scaleVal / 100.0;
    const stdW = 770.0;
    const stdH = 567.0;
    final showTop = config.enableTopBar;
    final showSidebar = config.enableSidebar;
    final showAnchor = config.enableAnchor;
    final showTicker = config.enableTicker;
    final brkTop = showTicker ? 765.0 : 897.0;

    final topNavBottom = showTop ? 148.0 : 0.0;
    final availH = math.max(100.0, brkTop - topNavBottom);
    final centerVerticalY = math.max(0.0, topNavBottom + (availH - stdH) / 2.0);

    double frameW = stdW;
    double frameH = stdH;
    double frameX = (1920.0 - stdW) / 2.0;
    double frameY = centerVerticalY;
    double anchorX = 100.0;

    if (scaleVal >= 100.0) {
      final t = math.min(1.0, (scaleVal - 100.0) / 150.0);
      frameW = stdW + (1920.0 - stdW) * t;
      frameH = stdH + (1080.0 - stdH) * t;
      final targetCenterY = (1080.0 - frameH) / 2.0;
      frameY = centerVerticalY + (targetCenterY - centerVerticalY) * t;
    } else {
      frameW = stdW * scale;
      frameH = stdH * scale;
      frameY = centerVerticalY + (stdH - frameH) / 2.0;
    }

    if (!showSidebar && !showAnchor) {
      frameX = (1920.0 - frameW) / 2.0;
      final freeH = brkTop - topNavBottom;
      frameY = topNavBottom + (freeH - frameH) / 2.0;
    } else if (showAnchor && showSidebar) {
      const openRight = 1000.0;
      final stdX = math.max(0.0, openRight + (1920.0 - openRight - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
      anchorX = 380.0;
    } else if (!showAnchor && showSidebar) {
      const openStart = 400.0;
      final openWidth = 1920.0 - openStart;
      final stdX = math.max(0.0, openStart + (openWidth - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
    } else if (showAnchor && !showSidebar) {
      anchorX = 100.0;
      const rightStart = 650.0;
      final rightWidth = 1920.0 - rightStart;
      final stdX = math.max(0.0, rightStart + (rightWidth - stdW) / 2.0);
      final targetCenterX = (1920.0 - frameW) / 2.0;
      final t = scaleVal >= 100.0 ? math.min(1.0, (scaleVal - 100.0) / 150.0) : 0.0;
      frameX = stdX * (1.0 - t) + targetCenterX * t;
    }

    return FrameLayout(
      x: frameX,
      y: frameY,
      w: frameW,
      h: frameH,
      anchorX: anchorX,
    );
  }

  static Future<ui.Image?> _tryLoadImage(String path) async {
    try {
      Uint8List bytes;
      if (path.startsWith('assets/')) {
        final ByteData data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List();
      } else {
        bytes = await File(path).readAsBytes();
      }
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      return frameInfo.image;
    } catch (_) {
      return null;
    }
  }

  /// Pure 100% Dynamic Broadcast Overlay Renderer
  /// Zero pre-rendered static plates. Everything is responsive to user toggles!
  static Future<String> generateOverlay({
    required BroadcastConfig config,
    required int targetWidth,
    required int targetHeight,
    String? customLogoPath,
  }) async {
    final isVertical = config.aspectRatio == "9:16";
    final double baseWidth = isVertical ? 1080.0 : 1920.0;
    final double baseHeight = isVertical ? 1920.0 : 1080.0;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final double scaleX = targetWidth / baseWidth;
    final double scaleY = targetHeight / baseHeight;

    // Current time & date calculations
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = "$hour:$minute $ampm";

    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    const hindiDays = ["रविवार", "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार"];
    final dateStr = "${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}";
    final dayStr = hindiDays[now.weekday % 7];

    // Load necessary channel assets
    final logoImg = await _tryLoadImage(customLogoPath ?? 'assets/web/logo.png') ??
        await _tryLoadImage('assets/web/logo.png');
    final palaceImg = await _tryLoadImage('assets/web/palace.jpg');
    final globeImg = await _tryLoadImage('assets/web/globe.jpg');
    final highwayImg = await _tryLoadImage('assets/web/highway.jpg');

    if (!isVertical) {
      // -------------------------------------------------------------
      // 16:9 LANDSCAPE BROADCAST MODE
      // -------------------------------------------------------------
      final layout = calculateFrameLayout(config);
      final brkTop = config.enableTicker ? 765.0 : 897.0;

      // 1. Top Bar (Header + Cards + Channel Logo)
      if (config.enableTopBar) {
        _drawLandscapeTopBar(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          logoImg: logoImg,
          palaceImg: palaceImg,
          globeImg: globeImg,
          highwayImg: highwayImg,
        );
      }

      // 2. Left Sidebar (Dynamic 1 to 5 Points)
      if (config.enableSidebar) {
        _drawLandscapeSidebar(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          items: config.sidebarItems,
        );
      }

      // 3. Studio Anchor Window (Picture-in-Picture)
      if (config.enableAnchor) {
        final anchorImg = await _tryLoadImage('assets/web/anchor.png');
        if (anchorImg != null) {
          final anchorY = (brkTop - 620.0) * scaleY;
          final anchorX = layout.anchorX * scaleX;
          final anchorW = 720.0 * scaleX;
          final anchorH = 620.0 * scaleY;
          canvas.drawImageRect(
            anchorImg,
            ui.Rect.fromLTWH(0, 0, anchorImg.width.toDouble(), anchorImg.height.toDouble()),
            ui.Rect.fromLTWH(anchorX, anchorY, anchorW, anchorH),
            ui.Paint(),
          );
        }
      }

      // 4. Location Pin Tag
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = (layout.x + 8.0) * scaleX;
        final locY = (layout.y + 10.0) * scaleY;
        _drawLocationTag(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          locX: locX,
          locY: locY,
          locationText: config.locationText,
        );
      }

      // 5. Breaking News Lower Third (Band + Text)
      _drawBreakingNewsBand(
        canvas: canvas,
        isVertical: false,
        scaleX: scaleX,
        scaleY: scaleY,
        brkTop: brkTop,
        headlineText: config.headlineText,
        subHeadlineText: config.subHeadline,
      );

      // 6. Bottom Ticker & Date/Time
      if (config.enableTicker) {
        _drawLandscapeBottomTicker(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          enableDateTime: config.enableDateTime,
          timeStr: timeStr,
          dateStr: dateStr,
          dayStr: dayStr,
          tickerTag: config.tickerTag,
          tickerText: config.tickerText,
        );
      }
    } else {
      // -------------------------------------------------------------
      // 9:16 VERTICAL REEL / SHORT BROADCAST MODE
      // -------------------------------------------------------------
      final topBound = config.enableTopBar ? 340.0 : 20.0;
      final brkTop = config.enableTicker ? 1150.0 : 1380.0;
      final availH = brkTop - topBound;
      final scaleVal = config.frameScale;
      final scale = scaleVal / 100.0;
      const stdW = 898.0;
      final stdH = math.min(717.0, availH * 0.88);

      double w, h;
      if (scaleVal >= 100.0) {
        final t = math.min(1.0, (scaleVal - 100.0) / 150.0);
        w = stdW + (1080.0 - stdW) * t;
        h = stdH + (availH - stdH) * t;
      } else {
        w = stdW * scale;
        h = stdH * scale;
      }
      final x = (1080.0 - w) / 2.0;
      final y = ((topBound + brkTop) / 2.0) - (h / 2.0);

      // 1. Portrait Top Bar
      if (config.enableTopBar) {
        _drawPortraitTopBar(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          logoImg: logoImg,
          palaceImg: palaceImg,
          globeImg: globeImg,
          highwayImg: highwayImg,
        );
      }

      // 2. Portrait Location Pin Tag
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = math.max(22.0, x + 10.0) * scaleX;
        final locY = math.max(topBound + 15.0, y + 17.0) * scaleY;
        _drawLocationTag(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          locX: locX,
          locY: locY,
          locationText: config.locationText,
        );
      }

      // 3. Portrait Breaking News Lower Third
      _drawBreakingNewsBand(
        canvas: canvas,
        isVertical: true,
        scaleX: scaleX,
        scaleY: scaleY,
        brkTop: brkTop,
        headlineText: config.headlineText,
        subHeadlineText: config.subHeadline,
      );

      // 4. Portrait Bottom Ticker & Date/Time
      if (config.enableTicker) {
        _drawPortraitBottomTicker(
          canvas: canvas,
          scaleX: scaleX,
          scaleY: scaleY,
          enableDateTime: config.enableDateTime,
          timeStr: timeStr,
          dateStr: dateStr,
          dayStr: dayStr,
          tickerTag: config.tickerTag,
          tickerText: config.tickerText,
        );
      }
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidth, targetHeight);
    final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) {
      throw Exception('Failed to encode broadcast overlay PNG.');
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final overlayFile = File('${tempDir.path}/dynamic_broadcast_overlay_$timestamp.png');
    await overlayFile.writeAsBytes(pngBytes.buffer.asUint8List());

    return overlayFile.path;
  }

  // ---------------------------------------------------------------------------
  // 1. LANDSCAPE TOP BAR
  // ---------------------------------------------------------------------------
  static void _drawLandscapeTopBar({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    ui.Image? logoImg,
    ui.Image? palaceImg,
    ui.Image? globeImg,
    ui.Image? highwayImg,
  }) {
    // Top Bar shadow/gradient base
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, 1920 * scaleX, 148 * scaleY),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, 0),
          ui.Offset(0, 148 * scaleY),
          [
            const Color(0xDD000000),
            const Color(0x66000000),
            const Color(0x00000000),
          ],
        ),
    );

    // Left Title Box: "आज की बड़ी खबर"
    final pathRed = ui.Path()
      ..moveTo(28 * scaleX, 22 * scaleY)
      ..lineTo(240 * scaleX, 22 * scaleY)
      ..lineTo(210 * scaleX, 118 * scaleY)
      ..lineTo(28 * scaleX, 118 * scaleY)
      ..close();
    canvas.drawPath(
      pathRed,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(28 * scaleX, 22 * scaleY),
          ui.Offset(240 * scaleX, 118 * scaleY),
          [const Color(0xFFD30202), const Color(0xFF8B0000)],
        ),
    );

    final pathYellow = ui.Path()
      ..moveTo(240 * scaleX, 22 * scaleY)
      ..lineTo(560 * scaleX, 22 * scaleY)
      ..lineTo(530 * scaleX, 118 * scaleY)
      ..lineTo(210 * scaleX, 118 * scaleY)
      ..close();
    canvas.drawPath(
      pathYellow,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(240 * scaleX, 22 * scaleY),
          ui.Offset(560 * scaleX, 118 * scaleY),
          [const Color(0xFFFFEB3B), const Color(0xFFFBC02D)],
        ),
    );

    _paintText(
      canvas: canvas,
      text: "आज की",
      offset: ui.Offset(50 * scaleX, 42 * scaleY),
      style: TextStyle(color: Colors.white, fontSize: 44 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );
    _paintText(
      canvas: canvas,
      text: "बड़ी खबर",
      offset: ui.Offset(260 * scaleX, 42 * scaleY),
      style: TextStyle(color: Colors.black, fontSize: 44 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );

    // 3 Cards
    final cards = [
      {'img': palaceImg, 'line1': 'प्रदेश की हर खबर', 'line2': 'सबसे पहले'},
      {'img': globeImg, 'line1': 'देश-दुनिया की', 'line2': 'ताजा अपडेट'},
      {'img': highwayImg, 'line1': 'आपके शहर की', 'line2': 'हर छोटी-बड़ी खबर'},
    ];

    for (int i = 0; i < 3; i++) {
      final cardX = (580 + i * 350) * scaleX;
      final cardY = 22 * scaleY;
      final cardW = 330 * scaleX;
      final cardH = 96 * scaleY;

      // Card Background
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(cardX, cardY, cardW, cardH), ui.Radius.circular(8 * scaleX)),
        ui.Paint()..color = Colors.white,
      );
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(cardX, cardY, cardW, cardH), ui.Radius.circular(8 * scaleX)),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.5 * scaleX
          ..color = const Color(0xFFE0E0E0),
      );

      // Card Thumbnail
      final cImg = cards[i]['img'] as ui.Image?;
      if (cImg != null) {
        canvas.drawImageRect(
          cImg,
          ui.Rect.fromLTWH(0, 0, cImg.width.toDouble(), cImg.height.toDouble()),
          ui.Rect.fromLTWH(cardX + 8 * scaleX, cardY + 8 * scaleY, 80 * scaleX, 80 * scaleY),
          ui.Paint(),
        );
      }

      // Card Text
      _paintText(
        canvas: canvas,
        text: cards[i]['line1'] as String,
        offset: ui.Offset(cardX + 96 * scaleX, cardY + 16 * scaleY),
        style: TextStyle(color: const Color(0xFF222222), fontSize: 18 * scaleY, fontWeight: FontWeight.w600, fontFamily: 'Hind'),
      );
      _paintText(
        canvas: canvas,
        text: cards[i]['line2'] as String,
        offset: ui.Offset(cardX + 96 * scaleX, cardY + 48 * scaleY),
        style: TextStyle(color: const Color(0xFFCF1620), fontSize: 20 * scaleY, fontWeight: FontWeight.w800, fontFamily: 'Hind'),
      );
    }

    // Top Right Channel Logo Card
    final logoCardX = 1650 * scaleX;
    final logoCardY = 16 * scaleY;
    final logoCardW = 240 * scaleX;
    final logoCardH = 105 * scaleY;

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(logoCardX, logoCardY, logoCardW, logoCardH), ui.Radius.circular(12 * scaleX)),
      ui.Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(logoCardX, logoCardY, logoCardW, logoCardH), ui.Radius.circular(12 * scaleX)),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2 * scaleX
        ..color = const Color(0xFFFFD54F),
    );

    if (logoImg != null) {
      canvas.drawImageRect(
        logoImg,
        ui.Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
        ui.Rect.fromLTWH(logoCardX + 10 * scaleX, logoCardY + 8 * scaleY, logoCardW - 20 * scaleX, logoCardH - 16 * scaleY),
        ui.Paint(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 2. PORTRAIT TOP BAR
  // ---------------------------------------------------------------------------
  static void _drawPortraitTopBar({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    ui.Image? logoImg,
    ui.Image? palaceImg,
    ui.Image? globeImg,
    ui.Image? highwayImg,
  }) {
    // Title Box: "आज की बड़ी खबर"
    final pathRed = ui.Path()
      ..moveTo(20 * scaleX, 40 * scaleY)
      ..lineTo(360 * scaleX, 40 * scaleY)
      ..lineTo(320 * scaleX, 180 * scaleY)
      ..lineTo(20 * scaleX, 180 * scaleY)
      ..close();
    canvas.drawPath(
      pathRed,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(20 * scaleX, 40 * scaleY),
          ui.Offset(360 * scaleX, 180 * scaleY),
          [const Color(0xFFD30202), const Color(0xFF8B0000)],
        ),
    );

    final pathYellow = ui.Path()
      ..moveTo(360 * scaleX, 40 * scaleY)
      ..lineTo(680 * scaleX, 40 * scaleY)
      ..lineTo(640 * scaleX, 180 * scaleY)
      ..lineTo(320 * scaleX, 180 * scaleY)
      ..close();
    canvas.drawPath(
      pathYellow,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(360 * scaleX, 40 * scaleY),
          ui.Offset(680 * scaleX, 180 * scaleY),
          [const Color(0xFFFFEB3B), const Color(0xFFFBC02D)],
        ),
    );

    _paintText(
      canvas: canvas,
      text: "आज की",
      offset: ui.Offset(65 * scaleX, 75 * scaleY),
      style: TextStyle(color: Colors.white, fontSize: 62 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );
    _paintText(
      canvas: canvas,
      text: "बड़ी खबर",
      offset: ui.Offset(375 * scaleX, 75 * scaleY),
      style: TextStyle(color: Colors.black, fontSize: 62 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );

    // Channel Logo Box at Top Right
    final logoCardX = 700 * scaleX;
    final logoCardY = 40 * scaleY;
    final logoCardW = 350 * scaleX;
    final logoCardH = 140 * scaleY;

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(logoCardX, logoCardY, logoCardW, logoCardH), ui.Radius.circular(16 * scaleX)),
      ui.Paint()..color = Colors.white,
    );
    if (logoImg != null) {
      canvas.drawImageRect(
        logoImg,
        ui.Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
        ui.Rect.fromLTWH(logoCardX + 15 * scaleX, logoCardY + 12 * scaleY, logoCardW - 30 * scaleX, logoCardH - 24 * scaleY),
        ui.Paint(),
      );
    }

    // 3 Cards Strip at y = 220
    final cards = [
      {'img': palaceImg, 'line1': 'प्रदेश की हर खबर', 'line2': 'सबसे पहले'},
      {'img': globeImg, 'line1': 'देश-दुनिया की', 'line2': 'ताजा अपडेट'},
      {'img': highwayImg, 'line1': 'आपके शहर की', 'line2': 'हर छोटी-बड़ी खबर'},
    ];

    for (int i = 0; i < 3; i++) {
      final cardX = (20 + i * 350) * scaleX;
      final cardY = 210 * scaleY;
      final cardW = 330 * scaleX;
      final cardH = 100 * scaleY;

      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(cardX, cardY, cardW, cardH), ui.Radius.circular(10 * scaleX)),
        ui.Paint()..color = Colors.white,
      );

      final cImg = cards[i]['img'] as ui.Image?;
      if (cImg != null) {
        canvas.drawImageRect(
          cImg,
          ui.Rect.fromLTWH(0, 0, cImg.width.toDouble(), cImg.height.toDouble()),
          ui.Rect.fromLTWH(cardX + 10 * scaleX, cardY + 10 * scaleY, 80 * scaleX, 80 * scaleY),
          ui.Paint(),
        );
      }

      _paintText(
        canvas: canvas,
        text: cards[i]['line1'] as String,
        offset: ui.Offset(cardX + 100 * scaleX, cardY + 16 * scaleY),
        style: TextStyle(color: const Color(0xFF222222), fontSize: 20 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind'),
      );
      _paintText(
        canvas: canvas,
        text: cards[i]['line2'] as String,
        offset: ui.Offset(cardX + 100 * scaleX, cardY + 50 * scaleY),
        style: TextStyle(color: const Color(0xFFCF1620), fontSize: 22 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 3. LANDSCAPE LEFT SIDEBAR
  // ---------------------------------------------------------------------------
  static void _drawLandscapeSidebar({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    required List<String> items,
  }) {
    final active = items.where((s) => s.trim().isNotEmpty).toList();
    if (active.isEmpty) {
      active.addAll([
        "भोपाल से इस वक्त की बड़ी खबर",
        "प्रदेश में मौसम को लेकर नया अपडेट",
        "यातायात व्यवस्था में हुआ बड़ा बदलाव",
      ]);
    }

    final double sbH = math.min(610.0, 95.0 + active.length * 98.0) * scaleY;
    final double sbX = 20 * scaleX;
    final double sbY = 155 * scaleY;
    final double sbW = 390 * scaleX;

    // Sidebar Container
    final rrect = ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(sbX, sbY, sbW, sbH), ui.Radius.circular(14 * scaleX));
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(sbX, sbY),
          ui.Offset(sbX, sbY + sbH),
          [const Color(0xFF99000A), const Color(0xFF6E0007)],
        ),
    );
    canvas.drawRRect(
      rrect,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.5 * scaleX
        ..color = const Color(0xFFE5A93C),
    );

    // Title: मुख्य खबरें
    _paintText(
      canvas: canvas,
      text: "मुख्य खबरें",
      offset: ui.Offset(sbX + 24 * scaleX, sbY + 16 * scaleY),
      style: TextStyle(
        color: const Color(0xFFFFEB3B),
        fontSize: 32 * scaleY,
        fontWeight: FontWeight.w900,
        fontFamily: 'Hind',
        shadows: const [Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4)],
      ),
    );

    // 1 to 5 Bullet Items
    for (int i = 0; i < math.min(5, active.length); i++) {
      final itemY = sbY + (72 + i * 98) * scaleY;

      // Number badge
      final numBox = ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(sbX + 20 * scaleX, itemY + 8 * scaleY, 48 * scaleX, 48 * scaleY),
        ui.Radius.circular(6 * scaleX),
      );
      canvas.drawRRect(numBox, ui.Paint()..color = const Color(0xFFFFC107));
      _paintText(
        canvas: canvas,
        text: "0${i + 1}",
        offset: ui.Offset(sbX + 28 * scaleX, itemY + 16 * scaleY),
        style: TextStyle(color: Colors.black, fontSize: 22 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
      );

      // Headline Text
      final textPainter = TextPainter(
        text: TextSpan(
          text: active[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: 20 * scaleY,
            fontWeight: FontWeight.w700,
            fontFamily: 'Hind',
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '...',
      );
      textPainter.layout(maxWidth: sbW - (90 * scaleX));
      textPainter.paint(canvas, ui.Offset(sbX + 78 * scaleX, itemY + 12 * scaleY));
    }
  }

  // ---------------------------------------------------------------------------
  // 4. LOCATION PIN TAG
  // ---------------------------------------------------------------------------
  static void _drawLocationTag({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    required double locX,
    required double locY,
    required String locationText,
  }) {
    final cleanLoc = locationText.replaceAll('📍', '').trim();
    if (cleanLoc.isEmpty) return;

    final locPainter = TextPainter(
      text: TextSpan(
        text: cleanLoc,
        style: TextStyle(color: Colors.white, fontSize: 26 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind'),
      ),
      textDirection: TextDirection.ltr,
    );
    locPainter.layout();

    final tagW = locPainter.width + (64 * scaleX);
    final tagH = 50 * scaleY;

    // Dark Blue Container
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(locX, locY, tagW, tagH), ui.Radius.circular(8 * scaleX)),
      ui.Paint()..color = const Color(0xFF001A3C),
    );

    // Red Box on Left for Pin
    canvas.drawRRect(
      ui.RRect.fromRectAndCorners(
        ui.Rect.fromLTWH(locX, locY, 46 * scaleX, tagH),
        topLeft: ui.Radius.circular(8 * scaleX),
        bottomLeft: ui.Radius.circular(8 * scaleX),
      ),
      ui.Paint()..color = const Color(0xFFE70A24),
    );

    // White Map Pin SVG Icon
    final pinCenterX = locX + 23 * scaleX;
    final pinCenterY = locY + 20 * scaleY;
    canvas.drawCircle(ui.Offset(pinCenterX, pinCenterY), 8 * scaleX, ui.Paint()..color = Colors.white);
    final pinPath = ui.Path()
      ..moveTo(pinCenterX - 7 * scaleX, pinCenterY + 4 * scaleY)
      ..lineTo(pinCenterX + 7 * scaleX, pinCenterY + 4 * scaleY)
      ..lineTo(pinCenterX, pinCenterY + 16 * scaleY)
      ..close();
    canvas.drawPath(pinPath, ui.Paint()..color = Colors.white);
    canvas.drawCircle(ui.Offset(pinCenterX, pinCenterY), 3.5 * scaleX, ui.Paint()..color = const Color(0xFFC4121F));

    // Location Text
    locPainter.paint(canvas, ui.Offset(locX + 54 * scaleX, locY + 8 * scaleY));
  }

  // ---------------------------------------------------------------------------
  // 5. BREAKING NEWS LOWER THIRD BAND
  // ---------------------------------------------------------------------------
  static void _drawBreakingNewsBand({
    required ui.Canvas canvas,
    required bool isVertical,
    required double scaleX,
    required double scaleY,
    required double brkTop,
    required String headlineText,
    required String subHeadlineText,
  }) {
    final double bandY = brkTop * scaleY;
    final double totalW = (isVertical ? 1080.0 : 1920.0) * scaleX;
    final double chevW = (isVertical ? 380.0 : 440.0) * scaleX;
    final double redBarH = 105 * scaleY;
    final double whiteBarH = 75 * scaleY;

    // 1. Red Headline Bar
    final redRect = ui.Rect.fromLTWH(chevW - 40 * scaleX, bandY, totalW - (chevW - 40 * scaleX), redBarH);
    canvas.drawRect(
      redRect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(redRect.left, bandY),
          ui.Offset(redRect.left, bandY + redBarH),
          [const Color(0xFFE60000), const Color(0xFFBA0000), const Color(0xFF7A0000)],
        ),
    );

    // Subtle Top Highlight on Red Bar
    canvas.drawLine(
      ui.Offset(redRect.left, bandY),
      ui.Offset(totalW, bandY),
      ui.Paint()..color = const Color(0xFFFF8A90)..strokeWidth = 2 * scaleY,
    );

    // 2. White Sub-Headline Bar
    final whiteRect = ui.Rect.fromLTWH(chevW - 40 * scaleX, bandY + redBarH, totalW - (chevW - 40 * scaleX), whiteBarH);
    canvas.drawRect(
      whiteRect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(whiteRect.left, bandY + redBarH),
          ui.Offset(whiteRect.left, bandY + redBarH + whiteBarH),
          [const Color(0xFFFFFFFF), const Color(0xFFEBEBEB)],
        ),
    );

    // 3. 3D Golden & Red Chevron Badge
    final chevPathOuter = ui.Path()
      ..moveTo(0, bandY)
      ..lineTo(chevW - 70 * scaleX, bandY)
      ..lineTo(chevW, bandY + 90 * scaleY)
      ..lineTo(chevW - 70 * scaleX, bandY + 180 * scaleY)
      ..lineTo(0, bandY + 180 * scaleY)
      ..close();
    canvas.drawPath(
      chevPathOuter,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, bandY),
          ui.Offset(chevW, bandY + 180 * scaleY),
          [const Color(0xFFFFEB3B), const Color(0xFFFFA000), const Color(0xFFE65100)],
        ),
    );

    final chevPathInner = ui.Path()
      ..moveTo(0, bandY + 8 * scaleY)
      ..lineTo(chevW - 85 * scaleX, bandY + 8 * scaleY)
      ..lineTo(chevW - 20 * scaleX, bandY + 90 * scaleY)
      ..lineTo(chevW - 85 * scaleX, bandY + 172 * scaleY)
      ..lineTo(0, bandY + 172 * scaleY)
      ..close();
    canvas.drawPath(
      chevPathInner,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, bandY + 8 * scaleY),
          ui.Offset(chevW, bandY + 172 * scaleY),
          [const Color(0xFFD30202), const Color(0xFF900000), const Color(0xFF5A0000)],
        ),
    );

    // Text: BREAKING
    _paintText(
      canvas: canvas,
      text: "BREAKING",
      offset: ui.Offset(45 * scaleX, bandY + 22 * scaleY),
      style: TextStyle(
        color: Colors.white,
        fontSize: (isVertical ? 54 : 58) * scaleY,
        fontWeight: FontWeight.w900,
        fontFamily: 'Hind',
        letterSpacing: 2 * scaleX,
        shadows: const [Shadow(color: Color(0xAA000000), offset: Offset(0, 4), blurRadius: 6)],
      ),
    );

    // Text: NEWS
    _paintText(
      canvas: canvas,
      text: "NEWS",
      offset: ui.Offset(78 * scaleX, bandY + 92 * scaleY),
      style: TextStyle(
        color: const Color(0xFFFFD54F),
        fontSize: (isVertical ? 74 : 78) * scaleY,
        fontWeight: FontWeight.w900,
        fontFamily: 'Hind',
        letterSpacing: 3 * scaleX,
        shadows: const [Shadow(color: Color(0xDD4A0000), offset: Offset(0, 4), blurRadius: 4)],
      ),
    );

    // 4. Headline Text
    final hlText = headlineText.trim().isNotEmpty ? headlineText.trim() : "श्री न्यूज़ 24x7 में आपका स्वागत है";
    final hlPainter = TextPainter(
      text: TextSpan(
        text: hlText,
        style: TextStyle(
          color: Colors.white,
          fontSize: (isVertical ? 44 : 46) * scaleY,
          fontWeight: FontWeight.w800,
          fontFamily: 'Hind',
          shadows: const [Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: isVertical ? 2 : 1,
      ellipsis: '...',
    );
    hlPainter.layout(maxWidth: totalW - chevW - 30 * scaleX);
    hlPainter.paint(canvas, ui.Offset(chevW + 20 * scaleX, bandY + 22 * scaleY));

    // 5. Sub-Headline Text
    final subText = subHeadlineText.trim().isNotEmpty ? subHeadlineText.trim() : "हम आपके लिए लाए हैं ताज़ा समाचार";
    final subPainter = TextPainter(
      text: TextSpan(
        text: subText,
        style: TextStyle(
          color: const Color(0xFF141414),
          fontSize: (isVertical ? 32 : 34) * scaleY,
          fontWeight: FontWeight.w700,
          fontFamily: 'Hind',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    subPainter.layout(maxWidth: totalW - chevW - 30 * scaleX);
    subPainter.paint(canvas, ui.Offset(chevW + 20 * scaleX, bandY + redBarH + 16 * scaleY));
  }

  // ---------------------------------------------------------------------------
  // 6. LANDSCAPE BOTTOM TICKER
  // ---------------------------------------------------------------------------
  static void _drawLandscapeBottomTicker({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    required bool enableDateTime,
    required String timeStr,
    required String dateStr,
    required String dayStr,
    required String tickerTag,
    required String tickerText,
  }) {
    const underY = 948.0;
    final double tagLeft = enableDateTime ? 445.0 * scaleX : 28.0 * scaleX;
    final double tagWidth = enableDateTime ? 250.0 * scaleX : 260.0 * scaleX;
    final double tickerLeft = enableDateTime ? 695.0 * scaleX : 288.0 * scaleX;
    final double tickerWidth = (1920.0 * scaleX) - tickerLeft;

    // Silver Underbar
    canvas.drawRect(
      ui.Rect.fromLTWH(0, underY * scaleY, 1920 * scaleX, 132 * scaleY),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(0, underY * scaleY),
          ui.Offset(1920 * scaleX, underY * scaleY),
          const [
            Color(0xFFD6D4D4),
            Color(0xFFE9C0CC),
            Color(0xFFFAF1F2),
            Color(0xFFF2EEEE),
            Color(0xFFDEDEDE),
          ],
          const [0.0, 0.16, 0.45, 0.70, 1.0],
        ),
    );

    // Live Date & Time
    if (enableDateTime) {
      // Time Box
      canvas.drawRRect(
        ui.RRect.fromRectAndCorners(
          ui.Rect.fromLTWH(30 * scaleX, 970 * scaleY, 215 * scaleX, 88 * scaleY),
          topLeft: ui.Radius.circular(12 * scaleX),
          bottomLeft: ui.Radius.circular(12 * scaleX),
        ),
        ui.Paint()..color = const Color(0xFFE11D2A),
      );
      _paintText(
        canvas: canvas,
        text: timeStr,
        offset: ui.Offset(48 * scaleX, 988 * scaleY),
        style: TextStyle(color: Colors.white, fontSize: 34 * scaleY, fontWeight: FontWeight.w800, fontFamily: 'Hind'),
      );

      // Date Box
      canvas.drawRect(
        ui.Rect.fromLTWH(245 * scaleX, 970 * scaleY, 200 * scaleX, 88 * scaleY),
        ui.Paint()..color = Colors.white,
      );
      _paintText(
        canvas: canvas,
        text: "$dateStr\n$dayStr",
        offset: ui.Offset(260 * scaleX, 980 * scaleY),
        style: TextStyle(color: Colors.black, fontSize: 20 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind', height: 1.15),
      );
    }

    // Ticker Tag: "ताजा खबर"
    final tagTitle = tickerTag.trim().isNotEmpty ? tickerTag.trim() : "ताजा खबर";
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(tagLeft, 970 * scaleY, tagWidth, 88 * scaleY),
        ui.Radius.circular(enableDateTime ? 0 : 8 * scaleX),
      ),
      ui.Paint()..color = const Color(0xFFE11D2A),
    );
    _paintText(
      canvas: canvas,
      text: tagTitle,
      offset: ui.Offset(tagLeft + 25 * scaleX, 988 * scaleY),
      style: TextStyle(color: Colors.white, fontSize: 34 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );

    // Ticker Text Strip (Dark Blue)
    final tText = tickerText.trim().isNotEmpty
        ? tickerText.trim()
        : "श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक";
    canvas.drawRect(
      ui.Rect.fromLTWH(tickerLeft, 970 * scaleY, tickerWidth, 88 * scaleY),
      ui.Paint()..color = const Color(0xFF0F1E4A),
    );
    final tickerPainter = TextPainter(
      text: TextSpan(
        text: tText,
        style: TextStyle(color: Colors.white, fontSize: 30 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind'),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    tickerPainter.layout(maxWidth: tickerWidth - 40 * scaleX);
    tickerPainter.paint(canvas, ui.Offset(tickerLeft + 20 * scaleX, 992 * scaleY));
  }

  // ---------------------------------------------------------------------------
  // 7. PORTRAIT BOTTOM TICKER
  // ---------------------------------------------------------------------------
  static void _drawPortraitBottomTicker({
    required ui.Canvas canvas,
    required double scaleX,
    required double scaleY,
    required bool enableDateTime,
    required String timeStr,
    required String dateStr,
    required String dayStr,
    required String tickerTag,
    required String tickerText,
  }) {
    const tickerY = 1538.0;
    final double tagLeft = enableDateTime ? 268.0 * scaleX : 15.0 * scaleX;
    final double tagWidth = enableDateTime ? 168.0 * scaleX : 200.0 * scaleX;
    final double tickerLeft = enableDateTime ? 436.0 * scaleX : 215.0 * scaleX;
    final double tickerWidth = (1080.0 * scaleX) - tickerLeft - 15.0 * scaleX;

    // Dark Blue Container
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(15 * scaleX, tickerY * scaleY, 1050 * scaleX, 88 * scaleY),
        ui.Radius.circular(12 * scaleX),
      ),
      ui.Paint()..color = const Color(0xFF011C3D),
    );

    // Live Date & Time
    if (enableDateTime) {
      // Time Box
      canvas.drawRRect(
        ui.RRect.fromRectAndCorners(
          ui.Rect.fromLTWH(15 * scaleX, tickerY * scaleY, 130 * scaleX, 88 * scaleY),
          topLeft: ui.Radius.circular(12 * scaleX),
          bottomLeft: ui.Radius.circular(12 * scaleX),
        ),
        ui.Paint()..color = const Color(0xFFE03030),
      );
      _paintText(
        canvas: canvas,
        text: timeStr,
        offset: ui.Offset(25 * scaleX, (tickerY + 28) * scaleY),
        style: TextStyle(color: Colors.white, fontSize: 24 * scaleY, fontWeight: FontWeight.w800, fontFamily: 'Hind'),
      );

      // Date Box
      canvas.drawRect(
        ui.Rect.fromLTWH(145 * scaleX, tickerY * scaleY, 123 * scaleX, 88 * scaleY),
        ui.Paint()..color = Colors.white,
      );
      _paintText(
        canvas: canvas,
        text: "$dateStr\n$dayStr",
        offset: ui.Offset(152 * scaleX, (tickerY + 20) * scaleY),
        style: TextStyle(color: Colors.black, fontSize: 18 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind', height: 1.15),
      );
    }

    // Ticker Tag: "ताजा खबर"
    final tagTitle = tickerTag.trim().isNotEmpty ? tickerTag.trim() : "ताजा खबर";
    canvas.drawRect(
      ui.Rect.fromLTWH(tagLeft, tickerY * scaleY, tagWidth, 88 * scaleY),
      ui.Paint()..color = const Color(0xFFE03030),
    );
    _paintText(
      canvas: canvas,
      text: tagTitle,
      offset: ui.Offset(tagLeft + 16 * scaleX, (tickerY + 24) * scaleY),
      style: TextStyle(color: Colors.white, fontSize: 28 * scaleY, fontWeight: FontWeight.w900, fontFamily: 'Hind'),
    );

    // Ticker Text
    final tText = tickerText.trim().isNotEmpty
        ? tickerText.trim()
        : "श्री न्यूज़ 24x7 | देश-दुनिया की हर बड़ी खबर | सबसे पहले और सबसे सटीक";
    final tickerPainter = TextPainter(
      text: TextSpan(
        text: tText,
        style: TextStyle(color: Colors.white, fontSize: 26 * scaleY, fontWeight: FontWeight.w700, fontFamily: 'Hind'),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
    );
    tickerPainter.layout(maxWidth: tickerWidth - 30 * scaleX);
    tickerPainter.paint(canvas, ui.Offset(tickerLeft + 16 * scaleX, (tickerY + 26) * scaleY));
  }

  static void _paintText({
    required ui.Canvas canvas,
    required String text,
    required ui.Offset offset,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, offset);
  }
}
