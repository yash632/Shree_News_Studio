import 'dart:io';
import 'dart:math' as math;
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

    double frameW, frameH, frameX, frameY;
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

  static Future<ui.Image> _loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    return frameInfo.image;
  }

  /// Generates the high-fidelity transparent broadcast overlay PNG
  static Future<String> generateOverlay({
    required BroadcastConfig config,
    required int targetWidth,
    required int targetHeight,
    String? customLogoPath,
  }) async {
    final isVertical = config.aspectRatio == "9:16";
    final plateAsset = isVertical
        ? 'assets/master_broadcast_plate_portrait.png'
        : 'assets/master_broadcast_plate.png';

    final ui.Image plate = await _loadAssetImage(plateAsset);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
    );

    final double scaleX = targetWidth / (isVertical ? 941.0 : 1920.0);
    final double scaleY = targetHeight / (isVertical ? 1672.0 : 1080.0);

    // 1. Draw master broadcast plate
    final srcRect = ui.Rect.fromLTWH(0, 0, plate.width.toDouble(), plate.height.toDouble());
    final dstRect = ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble());
    canvas.drawImageRect(plate, srcRect, dstRect, ui.Paint());

    if (!isVertical) {
      final layout = calculateFrameLayout(config);

      // 2. Clear frame window so footage shows through!
      if (config.frameScale < 180.0) {
        canvas.drawRect(
          ui.Rect.fromLTWH(
            layout.x * scaleX,
            layout.y * scaleY,
            layout.w * scaleX,
            layout.h * scaleY,
          ),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        // Full screen: clear whole central area behind graphics
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 148 * scaleY, targetWidth.toDouble(), (765 - 148) * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // 3. Top Bar Toggle
      if (!config.enableTopBar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), 155 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // 4. Sidebar Toggle & Items
      if (!config.enableSidebar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(20 * scaleX, 155 * scaleY, 390 * scaleX, 610 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        // Draw 5 Sidebar Headlines
        for (int i = 0; i < math.min(5, config.sidebarItems.length); i++) {
          final itemText = config.sidebarItems[i].trim();
          if (itemText.isNotEmpty) {
            final textPainter = TextPainter(
              text: TextSpan(
                text: itemText,
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: 20 * scaleY,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Hind',
                ),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 2,
              ellipsis: '...',
            );
            textPainter.layout(maxWidth: 220 * scaleX);
            textPainter.paint(
              canvas,
              ui.Offset(130 * scaleX, (250 + i * 98) * scaleY),
            );
          }
        }
      }

      // 5. Studio Anchor Window (Picture-in-Picture)
      if (config.enableAnchor) {
        try {
          final anchorImg = await _loadAssetImage('assets/web/anchor.png');
          final brkTop = config.enableTicker ? 765.0 : 897.0;
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
        } catch (_) {}
      }

      // 6. Location Tag Pin
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = (layout.x + 8.0) * scaleX;
        final locY = (layout.y + 10.0) * scaleY;
        final cleanLoc = config.locationText.replaceAll('📍', '').trim();

        final pinBgPaint = ui.Paint()..color = const Color(0xFF0D1F5C);
        final pinRedPaint = ui.Paint()..color = const Color(0xFFE11D2A);

        final locPainter = TextPainter(
          text: TextSpan(
            text: cleanLoc,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        locPainter.layout();

        final tagW = locPainter.width + (64 * scaleX);
        final tagH = 46 * scaleY;

        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(locX, locY, tagW, tagH),
            const ui.Radius.circular(4),
          ),
          pinBgPaint,
        );

        canvas.drawRect(
          ui.Rect.fromLTWH(locX, locY, 44 * scaleX, tagH),
          pinRedPaint,
        );

        locPainter.paint(canvas, ui.Offset(locX + 52 * scaleX, locY + 8 * scaleY));
      }

      // 7. Main News Headline (Hind-Bold Devanagari)
      if (config.headlineText.trim().isNotEmpty) {
        final double hlX = 545 * scaleX;
        final double hlY = (config.enableTicker ? 775 : 907) * scaleY;
        final double hlMaxW = 1335 * scaleX;
        final double hlFontSize = 46 * scaleY;

        final textPainter = TextPainter(
          text: TextSpan(
            text: config.headlineText.trim(),
            style: TextStyle(
              color: Colors.white,
              fontSize: hlFontSize,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hind',
              shadows: const [
                Shadow(color: Color(0x99000000), offset: Offset(0, 3), blurRadius: 4),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        textPainter.layout(maxWidth: hlMaxW);
        textPainter.paint(canvas, ui.Offset(hlX, hlY));
      }

      // 8. Sub-Headline
      if (config.subHeadline.trim().isNotEmpty) {
        final double subX = 545 * scaleX;
        final double subY = (config.enableTicker ? 880 : 1012) * scaleY;
        final double subMaxW = 1315 * scaleX;
        final double subFontSize = 32 * scaleY;

        final subPainter = TextPainter(
          text: TextSpan(
            text: config.subHeadline.trim(),
            style: TextStyle(
              color: const Color(0xFF141414),
              fontSize: subFontSize,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        subPainter.layout(maxWidth: subMaxW);
        subPainter.paint(canvas, ui.Offset(subX, subY));
      }

      // 9. Bottom Ticker Bar Toggle
      if (!config.enableTicker) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 948 * scaleY, targetWidth.toDouble(), 132 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      } else {
        // Draw Ticker Tag
        final tagPainter = TextPainter(
          text: TextSpan(
            text: config.tickerTag,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34 * scaleY,
              fontWeight: FontWeight.w900,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        tagPainter.layout();
        tagPainter.paint(canvas, ui.Offset(460 * scaleX, 985 * scaleY));

        // Draw Ticker Text
        final tickerPainter = TextPainter(
          text: TextSpan(
            text: config.tickerText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28 * scaleY,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        tickerPainter.layout(maxWidth: 1180 * scaleX);
        tickerPainter.paint(canvas, ui.Offset(720 * scaleX, 990 * scaleY));
      }
    } else {
      // 9:16 Portrait Mode
      // Clear central video frame hole
      final topBound = config.enableTopBar ? 340.0 : 20.0;
      final bottomBound = config.enableTicker ? 1150.0 : 1320.0;
      final availH = bottomBound - topBound;
      final scaleVal = config.frameScale;
      final scale = scaleVal / 100.0;
      final stdW = 898.0;
      final stdH = math.min(717.0, availH * 0.88);

      double w, h;
      if (scaleVal >= 100.0) {
        final t = math.min(1.0, (scaleVal - 100.0) / 150.0);
        w = stdW + (941.0 - stdW) * t;
        h = stdH + (availH - stdH) * t;
      } else {
        w = stdW * scale;
        h = stdH * scale;
      }
      final x = (941.0 - w) / 2.0;
      final y = ((topBound + bottomBound) / 2.0) - (h / 2.0);

      canvas.drawRect(
        ui.Rect.fromLTWH(x * scaleX, y * scaleY, w * scaleX, h * scaleY),
        ui.Paint()..blendMode = ui.BlendMode.clear,
      );

      // Top Bar Toggle
      if (!config.enableTopBar) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), 350 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }

      // Location Pin
      if (config.enableLocation && config.locationText.trim().isNotEmpty) {
        final locX = math.max(22.0, x + 10.0) * scaleX;
        final locY = math.max(topBound + 15.0, y + 17.0) * scaleY;
        final cleanLoc = config.locationText.replaceAll('📍', '').trim();

        final pinBgPaint = ui.Paint()..color = const Color(0xFF001A3C);
        final pinRedPaint = ui.Paint()..color = const Color(0xFFE70A24);

        final locPainter = TextPainter(
          text: TextSpan(
            text: cleanLoc,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26 * scaleY,
              fontWeight: FontWeight.w600,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        );
        locPainter.layout();

        final tagW = locPainter.width + (58 * scaleX);
        final tagH = 50 * scaleY;

        canvas.drawRRect(
          ui.RRect.fromRectAndRadius(
            ui.Rect.fromLTWH(locX, locY, tagW, tagH),
            const ui.Radius.circular(8),
          ),
          pinBgPaint,
        );

        canvas.drawRect(
          ui.Rect.fromLTWH(locX, locY, 44 * scaleX, tagH),
          pinRedPaint,
        );

        locPainter.paint(canvas, ui.Offset(locX + 50 * scaleX, locY + 10 * scaleY));
      }

      // Main News Headline
      if (config.headlineText.trim().isNotEmpty) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: config.headlineText.trim(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 42 * scaleY,
              fontWeight: FontWeight.w800,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        );
        textPainter.layout(maxWidth: 540 * scaleX);
        textPainter.paint(canvas, ui.Offset(377 * scaleX, 1210 * scaleY));
      }

      // Sub-Headline
      if (config.subHeadline.trim().isNotEmpty) {
        final subPainter = TextPainter(
          text: TextSpan(
            text: config.subHeadline.trim(),
            style: TextStyle(
              color: const Color(0xFF111111),
              fontSize: 34 * scaleY,
              fontWeight: FontWeight.w700,
              fontFamily: 'Hind',
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '...',
        );
        subPainter.layout(maxWidth: 850 * scaleX);
        subPainter.paint(canvas, ui.Offset(47 * scaleX, 1395 * scaleY));
      }

      // Ticker Toggle
      if (!config.enableTicker) {
        canvas.drawRect(
          ui.Rect.fromLTWH(0, 1450 * scaleY, targetWidth.toDouble(), 220 * scaleY),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
      }
    }

    // Custom Logo if supplied
    if (config.enableTopBar && customLogoPath != null && File(customLogoPath).existsSync()) {
      try {
        final logoBytes = await File(customLogoPath).readAsBytes();
        final logoCodec = await ui.instantiateImageCodec(logoBytes);
        final logoFrame = await logoCodec.getNextFrame();
        final logoImg = logoFrame.image;

        final logoX = (isVertical ? 622 : 1625) * scaleX;
        final logoY = (isVertical ? 45 : 0) * scaleY;
        final logoW = (isVertical ? 319 : 295) * scaleX;
        final logoH = (isVertical ? 170 : 172) * scaleY;

        canvas.drawRect(
          ui.Rect.fromLTWH(logoX, logoY, logoW, logoH),
          ui.Paint()..blendMode = ui.BlendMode.clear,
        );
        canvas.drawImageRect(
          logoImg,
          ui.Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
          ui.Rect.fromLTWH(logoX, logoY, logoW, logoH),
          ui.Paint(),
        );
      } catch (_) {}
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(targetWidth, targetHeight);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final overlayFile = File('${tempDir.path}/broadcast_overlay_$timestamp.png');
    await overlayFile.writeAsBytes(byteData!.buffer.asUint8List());

    return overlayFile.path;
  }
}
